-module(woody_ranch_metrics_collector).

-export([setup/0]).
-export([observe/1]).

%%

%% Кажется что стоит собирать метрики не просто по обслуживаемым запросам в
%% ковбое, но ещё и общему количесту активных соединений, а так же
%% непосредстввенных событий вуди с метками службы/операции для дополнения
%% метрик информацией о том откуда идут запросы к сервису.
-spec setup() -> ok.
setup() ->
    %% TODO
    ok.
%% prometheus_counter:declare([{name, woody_active_connections},
%%                             {registry, registry()},
%%                             {labels, []},
%%                             {help, "Number of active connections."}]),
%%   ok.

-spec observe(cowboy_metrics_h:metrics()) -> ok.
observe(_Metrics) ->
    ok.

%%

%% get_server_acceptors_info() ->
%%     ranch:info().
%%     %% {_Ref, [
%%     %%     {pid, Pid},
%%     %%     {status, Status},
%%     %%     {ip, IP},
%%     %%     {port, Port},
%%     %%     {max_connections, MaxConns},
%%     %%     {active_connections, ranch_conns_sup:active_connections(ConnsSup)},
%%     %%     {all_connections, proplists:get_value(active, supervisor:count_children(ConnsSup))},
%%     %%     {transport, Transport},
%%     %%     {transport_options, TransOpts},
%%     %%     {protocol, Protocol},
%%     %%     {protocol_options, ProtoOpts}
%%     %% ]}.

%% registry() ->
%%     default.
