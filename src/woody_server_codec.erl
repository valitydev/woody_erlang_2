-module(woody_server_codec).

-type codec() :: module().

-export_type([codec/0]).
-export_type([invocation/0]).

-export([get_service_name/2]).

-export([read_call/3]).
-export([write_result/6]).

-export([catch_business_exception/4]).

-type buffer() :: iodata().
-type service() :: woody:service().
-type func() :: woody:func().
-type args() :: woody:args().
-type seqid() :: non_neg_integer().

-type invocation() :: {woody:rpc_type(), func(), args()}.

-type result() ::
    ok
    | {reply, woody:result()}
    | {exception, _Name, woody:result()}.

-callback get_service_name(service()) ->
    woody:service_name().

-callback read_call(buffer(), service()) ->
    {ok, seqid(), invocation(), _Rest :: buffer()}
    | {error, _Reason}.

-callback write_result(buffer(), service(), func(), result(), seqid()) ->
    {ok, buffer()}
    | {error, _Reason}.

%%

-spec get_service_name(codec(), service()) ->
    woody:service_name().
get_service_name(thrift_processor_codec, {_Module, Service}) ->
    Service;
get_service_name(Codec, Service) ->
    Codec:get_service_name(Service).

-spec read_call(codec(), buffer(), service()) ->
    {ok, seqid(), invocation(), _Rest :: buffer()}
    | {error, _Reason}.
read_call(thrift_processor_codec, Buffer, Service) ->
    case thrift_processor_codec:read_function_call(Buffer, thrift_strict_binary_codec, Service) of
        {ok, SeqId, {Type, Function, Args}, Rest} ->
            RpcType = maps:get(Type, #{call => call, oneway => cast}),
            {ok, SeqId, {RpcType, Function, Args}, Rest};
        {error, _} = Error ->
            Error
    end;
read_call(Codec, Buffer, Service) ->
    Codec:read_call(Buffer, Service).

-spec write_result(codec(), buffer(), service(), func(), result(), seqid()) ->
    {ok, buffer()}
    | {error, _Reason}.
write_result(thrift_processor_codec, Buffer, Service, Function, {exception, _Name, {Type, Exception}}, SeqId) ->
    thrift_processor_codec:write_function_result(
        Buffer,
        thrift_strict_binary_codec,
        Service,
        Function,
        {exception, Type, Exception},
        SeqId
    );
write_result(thrift_processor_codec, Buffer, Service, Function, Res, SeqId) ->
    thrift_processor_codec:write_function_result(
        Buffer,
        thrift_strict_binary_codec,
        Service,
        Function,
        Res,
        SeqId
    );
write_result(Codec, Buffer, Service, Function, Res, SeqId) ->
    Codec:write_result(Buffer, Service, Function, Res, SeqId).

-spec catch_business_exception(codec(), service(), func(), _Exception) ->
    {exception, _Name :: atom(), _TypedException}
    | {error, _Reason}.
catch_business_exception(thrift_processor_codec, Service, Function, Exception) ->
    case thrift_processor_codec:match_exception(Service, Function, Exception) of
        {ok, Type} ->
            {exception, get_exception_name(Type, Exception), {Type, Exception}};
        {error, _} = Error ->
            Error
    end;
catch_business_exception(_Codec, _Service, _Function, _Exception) ->
    {error, noimpl}.

-spec get_exception_name(_Type, woody:result()) ->
    atom().
get_exception_name({{struct, exception, {_Mod, Name}}, _}, _) ->
    Name;
get_exception_name(_Type, Exception) ->
    element(1, Exception).
