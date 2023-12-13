-module(woody_ranch_prometheus_collector).

-export([setup/0]).

%%

-behaviour(prometheus_collector).

-export([collect_mf/2]).
-export([collect_metrics/2]).
-export([deregister_cleanup/1]).

-define(CONNECTIONS, woody_ranch_listener_connections).

%% Installation

-spec setup() -> ok.
setup() ->
    prometheus_registry:register_collector(registry(), ?MODULE).

%% Collector API

-type data() :: [data_item()].
-type data_item() :: {data_labels(), non_neg_integer()}.
-type data_labels() :: [{atom(), atom() | nonempty_string() | binary() | iolist()}].
-type maybe_woody_server_ref() :: {module(), ID :: atom()} | ranch:ref().
-type ranch_info() ::
    [{maybe_woody_server_ref(), [{atom(), any()}]}]
    | #{maybe_woody_server_ref() => #{atom() => any()}}.

-spec collect_mf(prometheus_registry:registry(), prometheus_collector:collect_mf_callback()) -> ok.
collect_mf(_Registry, Callback) ->
    F = fun({ListenerRef, ListenerInfo}) ->
        make_listener_data(ListenerRef, ListenerInfo)
    end,
    Data = lists:flatten(lists:map(F, get_listeners_info())),
    Callback(create_gauge(Data)).

-spec collect_metrics(prometheus_metric:name(), data()) ->
    prometheus_model:'Metric'() | [prometheus_model:'Metric'()].
collect_metrics(_Name, Data) ->
    [prometheus_model_helpers:gauge_metric(Labels, Value) || {Labels, Value} <- Data].

-spec deregister_cleanup(prometheus_registry:registry()) -> ok.
deregister_cleanup(_Registry) ->
    %% Nothing to clean up
    ok.

%% Private

registry() ->
    default.

-spec create_gauge(data()) -> prometheus_model:'MetricFamily'().
create_gauge(Data) ->
    Help = "Number of active connections",
    prometheus_model_helpers:create_mf(?CONNECTIONS, Help, gauge, ?MODULE, Data).

-spec make_listener_data(maybe_woody_server_ref(), #{atom() => any()}) -> data().
make_listener_data(Ref, #{active_connections := V}) ->
    Labels = [{listener, Ref}],
    [{Labels, V}];
make_listener_data(_Ref, _Info) ->
    [].

get_listeners_info() ->
    lists:filter(
        fun
            ({_Ref, #{active_connections := _}}) -> true;
            (_Else) -> false
        end,
        %% See https://ninenines.eu/docs/en/ranch/1.8/guide/listeners/#_obtaining_information_about_listeners
        normalize_listeners_info(ranch:info())
    ).

-dialyzer({no_match, normalize_listeners_info/1}).
-spec normalize_listeners_info(ranch_info()) -> [{maybe_woody_server_ref(), #{atom() => any()}}].
%% Ranch v2
normalize_listeners_info(#{} = Info) ->
    maps:to_list(Info);
%% Ranch v1
normalize_listeners_info(Info) ->
    lists:map(fun({Ref, ListenerInfo}) -> {Ref, maps:from_list(ListenerInfo)} end, Info).
