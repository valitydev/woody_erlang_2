-module(woody_hackney_prometheus_collector).

-export([setup/0]).

%%

-behaviour(prometheus_collector).

-export([collect_mf/2]).
-export([collect_metrics/2]).
-export([deregister_cleanup/1]).

-define(POOL_USAGE, woody_hackney_pool_usage).

%% Installation

%% @doc Installs custom collector for hackney's pool metrics
-spec setup() -> ok.
setup() ->
    prometheus_registry:register_collector(registry(), ?MODULE).

%% Collector API

-type data() :: [data_item()].
-type data_item() :: {data_labels(), non_neg_integer()}.
-type data_labels() :: [{atom(), atom() | nonempty_string() | binary() | iolist()}].
-type pool_stats() :: [{atom(), any()}].

-spec collect_mf(prometheus_registry:registry(), prometheus_collector:collect_mf_callback()) -> ok.
collect_mf(_Registry, Callback) ->
    F = fun({Pool, _Pid}) ->
        make_pool_data(Pool, get_pool_stats(Pool))
    end,
    Data = lists:flatten(lists:map(F, get_hackney_pools())),
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

get_pool_stats(Pool) ->
    %% NOTE It looks like 'hackney_pool' table data can occasionally contain
    %%      dead pools
    try
        hackney_pool:get_stats(Pool)
    catch
        %% "Time to make the chimi-fuckin'-changas."
        exit:{noproc, _Reason} ->
            []
    end.

-spec create_gauge(data()) -> prometheus_model:'MetricFamily'().
create_gauge(Data) ->
    Help = "Connection pool status by used, free and queued connections count",
    prometheus_model_helpers:create_mf(?POOL_USAGE, Help, gauge, ?MODULE, Data).

-spec make_pool_data(atom(), pool_stats()) -> data().
make_pool_data(Pool, Stats0) ->
    Stats1 = maps:with([in_use_count, free_count, queue_count], maps:from_list(Stats0)),
    lists:foldl(fun({S, V}, Data) -> [make_data_item(Pool, S, V) | Data] end, [], maps:to_list(Stats1)).

make_data_item(Pool, Status, Value) ->
    Labels = [{pool, Pool}, {status, Status}],
    {Labels, Value}.

get_hackney_pools() ->
    %% Shamelessly pasted from
    %% https://github.com/soundtrackyourbrand/prometheus-hackney-collector
    %%
    %% Basically, we rely on not publicly exposed table containing started pools
    %% under hackney's hood.
    ets:tab2list(hackney_pool).
