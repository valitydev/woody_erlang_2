-module(woody_client_codec).

-type codec() :: module().

-export_type([codec/0]).

-export([get_service_name/2]).
-export([get_rpc_type/3]).

-export([write_call/6]).
-export([read_result/5]).

-type buffer() :: iodata().
-type service() :: woody:service().
-type func() :: woody:func().
-type args() :: woody:args().
-type seqid() :: non_neg_integer().

-type result() ::
    ok
    | {reply, woody:result()}
    | {exception, woody:result()}.

-callback get_service_name(service()) ->
    woody:service_name().

-callback get_rpc_type(service(), func()) ->
    woody:rpc_type().

-callback write_call(buffer(), service(), func(), args(), seqid()) ->
    {ok, buffer()}
    | {error, _Reason}.

-callback read_result(buffer(), service(), func(), seqid()) ->
    {ok, result(), _Rest :: buffer()}
    | {error, _Reason}.

%%

-spec get_service_name(codec(), service()) ->
    woody:service_name().
get_service_name(thrift_client_codec, {_Module, Service}) ->
    Service;
get_service_name(Codec, Service) ->
    Codec:get_service_name(Service).

-spec get_rpc_type(codec(), service(), func()) ->
    woody:rpc_type().
get_rpc_type(thrift_client_codec, Service, Function) ->
    woody_util:get_rpc_type(Service, Function);
get_rpc_type(Codec, Service, Function) ->
    Codec:get_rpc_type(Service, Function).

-spec write_call(codec(), buffer(), service(), func(), args(), seqid()) ->
    {ok, buffer()}
    | {error, _Reason}.
write_call(thrift_client_codec, Buffer, Service, Function, Args, SeqId) ->
    thrift_client_codec:write_function_call(
        Buffer,
        thrift_strict_binary_codec,
        Service,
        Function,
        Args,
        SeqId
    );
write_call(Codec, Buffer, Service, Function, Args, SeqId) ->
    Codec:write_call(Buffer, Service, Function, Args, SeqId).

-spec read_result(codec(), buffer(), service(), func(), seqid()) ->
    {ok, result(), _Rest :: buffer()}
    | {error, _Reason}.
read_result(thrift_client_codec, Buffer, Service, Function, SeqId) ->
    thrift_client_codec:read_function_result(
        Buffer,
        thrift_strict_binary_codec,
        Service,
        Function,
        SeqId
    );
read_result(Codec, Buffer, Service, Function, SeqId) ->
    Codec:read_result(Buffer, Service, Function, SeqId).
