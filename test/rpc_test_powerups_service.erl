%%
%% Autogenerated by Thrift Compiler (1.0.0-dev)
%%
%% DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
%%

-module(rpc_test_powerups_service).
-behaviour(thrift_service).


-include("rpc_test_powerups_service.hrl").

-export([function_info/2]).
-export([struct_info/1]).
-export([function_names/0]).

function_names() -> 
    [
        'get_powerup',
        'like_powerup'
    ].

struct_info(_) -> erlang:error(badarg).

% get_powerup(This, Name, Data)
function_info('get_powerup', params_type) ->
    {struct, [
        {1, undefined, string, 'name', undefined},
        {2, undefined, string, 'data', undefined}
    ]};
function_info('get_powerup', reply_type) ->
    {struct, {rpc_test_types, 'powerup'}};
function_info('get_powerup', exceptions) ->
    {struct, [
        {1, undefined, {struct, {rpc_test_types, 'powerup_failure'}}, 'error', #'powerup_failure'{}}
    ]};
% like_powerup(This, Name, Data)
function_info('like_powerup', params_type) ->
    {struct, [
        {1, undefined, string, 'name', undefined},
        {2, undefined, string, 'data', undefined}
    ]};
function_info('like_powerup', reply_type) ->
    oneway_void;
function_info('like_powerup', exceptions) ->
    {struct, []};
function_info(_Func, _Info) -> erlang:error(badarg).

