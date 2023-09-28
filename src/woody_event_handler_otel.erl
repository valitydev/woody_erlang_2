-module(woody_event_handler_otel).

-include_lib("opentelemetry_api/include/opentelemetry.hrl").
-include("woody_defs.hrl").

-behaviour(woody_event_handler).

-export([handle_event/4]).

-spec handle_event(Event, RpcId, Meta, Opts) -> ok when
    Event :: woody_event_handler:event(),
    RpcId :: woody:rpc_id() | undefined,
    Meta :: woody_event_handler:event_meta(),
    Opts :: woody:options().

-define(IS_SPAN_START(Event), Event =:= ?EV_CALL_SERVICE orelse Event =:= ?EV_INVOKE_SERVICE_HANDLER).
-define(IS_SPAN_END(Event), Event =:= ?EV_SERVICE_RESULT orelse Event =:= ?EV_SERVICE_HANDLER_RESULT).
-define(IS_CLIENT_INTERNAL(Event),
    Event =:= ?EV_CLIENT_CACHE_HIT orelse
        Event =:= ?EV_CLIENT_CACHE_MISS orelse
        Event =:= ?EV_CLIENT_CACHE_UPDATE orelse
        Event =:= ?EV_CLIENT_SEND orelse
        Event =:= ?EV_CLIENT_RECEIVE
).

%% Client events
handle_event(Event, RpcID, _Meta = #{url := Url}, _Opts) when ?IS_CLIENT_INTERNAL(Event) ->
    otel_with_span(otel_ctx:get_current(), mk_ref(RpcID), fun(SpanCtx) ->
        _ = otel_span:add_event(SpanCtx, atom_to_binary(Event), #{url => Url})
    end);
%% Internal error handling
handle_event(?EV_INTERNAL_ERROR, RpcID, Meta = #{error := Error, class := Class, reason := Reason}, _Opts) ->
    Stacktrace = maps:get(stack, Meta, []),
    Details = io_lib:format("~ts: ~ts", [Error, Reason]),
    otel_with_span(otel_ctx:get_current(), mk_ref(RpcID), fun(SpanCtx) ->
        _ = otel_span:record_exception(SpanCtx, genlib:define(Class, error), Details, Stacktrace, #{}),
        otel_maybe_cleanup(Meta, SpanCtx)
    end);
%% Registers span starts/ends for woody client calls and woody server function invocations.
handle_event(Event, RpcID, Meta, _Opts) when ?IS_SPAN_START(Event) ->
    Tracer = opentelemetry:get_application_tracer(?MODULE),
    otel_span_start(Tracer, otel_ctx:get_current(), mk_ref(RpcID), mk_name(Meta), mk_opts(Event));
handle_event(Event, RpcID, Meta, _Opts) when ?IS_SPAN_END(Event) ->
    otel_span_end(otel_ctx:get_current(), mk_ref(RpcID), fun(SpanCtx) ->
        otel_maybe_erroneous_result(SpanCtx, Meta)
    end);
handle_event(_Event, _RpcID, _Meta, _Opts) ->
    ok.

%% In-process span helpers
%% NOTE Those helpers are designed specifically to manage stacking spans during
%%      woody client (or server) calls _inside_ one single process context.
%%      Thus, use of process dictionary via `otel_ctx'.

-define(SPANS_STACK, 'spans_ctx_stack').

otel_span_start(Tracer, Ctx, SpanKey, SpanName, Opts) ->
    SpanCtx = otel_tracer:start_span(Ctx, Tracer, SpanName, Opts),
    Ctx1 = record_current_span_ctx(SpanKey, SpanCtx, Ctx),
    Ctx2 = otel_tracer:set_current_span(Ctx1, SpanCtx),
    _ = otel_ctx:attach(Ctx2),
    ok.

record_current_span_ctx(Key, SpanCtx, Ctx) ->
    Stack = otel_ctx:get_value(Ctx, ?SPANS_STACK, []),
    Entry = {Key, SpanCtx, otel_tracer:current_span_ctx(Ctx)},
    otel_ctx:set_value(Ctx, ?SPANS_STACK, [Entry | Stack]).

otel_span_end(Ctx, SpanKey, OnBeforeEnd) ->
    Stack = otel_ctx:get_value(Ctx, ?SPANS_STACK, []),
    %% NOTE Only first occurrence is taken
    case lists:keytake(SpanKey, 1, Stack) of
        false ->
            ok;
        {value, {_Key, SpanCtx, ParentSpanCtx}, Stack1} ->
            SpanCtx1 = OnBeforeEnd(SpanCtx),
            _ = otel_span:end_span(SpanCtx1, undefined),
            Ctx1 = otel_ctx:set_value(Ctx, ?SPANS_STACK, Stack1),
            Ctx2 = otel_tracer:set_current_span(Ctx1, ParentSpanCtx),
            _ = otel_ctx:attach(Ctx2),
            ok
    end.

otel_with_span(Ctx, SpanKey, F) ->
    Stack = otel_ctx:get_value(Ctx, ?SPANS_STACK, []),
    %% Find one in stack by key or use whatever current span is in otel context
    _ =
        case lists:keyfind(SpanKey, 1, Stack) of
            false ->
                F(otel_tracer:current_span_ctx(Ctx));
            {_Key, SpanCtx, _ParentSpanCtx} ->
                F(SpanCtx)
        end,
    ok.

otel_maybe_cleanup(#{final := true}, SpanCtx) ->
    _ = otel_span:end_span(SpanCtx, undefined),
    otel_ctx:clear(),
    ok;
otel_maybe_cleanup(_Meta, _SpanCtx) ->
    ok.

otel_maybe_erroneous_result(SpanCtx, Meta = #{status := error, result := Reason}) ->
    Class = maps:get(except_class, Meta, error),
    Stacktrace = maps:get(stack, Meta, []),
    _ = otel_span:record_exception(SpanCtx, Class, Reason, Stacktrace, #{}),
    SpanCtx;
otel_maybe_erroneous_result(SpanCtx, _Meta) ->
    SpanCtx.

mk_opts(?EV_CALL_SERVICE) ->
    #{kind => ?SPAN_KIND_CLIENT};
mk_opts(?EV_INVOKE_SERVICE_HANDLER) ->
    #{kind => ?SPAN_KIND_SERVER};
mk_opts(_Event) ->
    #{}.

mk_ref(#{span_id := WoodySpanId}) ->
    WoodySpanId.

mk_name(#{role := Role, service := Service, function := Function}) ->
    woody_util:to_binary([Role, " ", Service, ":", Function]).
