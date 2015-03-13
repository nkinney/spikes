-module(simple_worker).
-behaviour(gen_server).

-include_lib("eunit/include/eunit.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-export([start_link/1, start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record (state, {domain_module, topics}).

exchange() -> <<"simple_worker_exchange">>.

default_topics(DomainModule) -> [ {"any","any","any","any"},
                                  {"workers","any","any","any"},
                                  {"workers","any",atom_to_list(DomainModule),"any"} ].

format_topics(Topics) ->
    lists:map(fun(Tuple) -> list_to_binary(string:join(tuple_to_list(Tuple), ".")) end,
              Topics).

start_link(DomainModule) -> start_link(DomainModule, default_topics(DomainModule)).

start_link(DomainModule, Topics) ->
    gen_server:start_link({local, DomainModule}, ?MODULE, [DomainModule, format_topics(Topics)], []).

init([DomainModule, Topics]) ->
    {_Connection, Channel, Queue} = create_queue("localhost", Topics),
    io:format(" [*] Waiting for messages. To exit press CTRL+C~n"),
    amqp_channel:subscribe(Channel, #'basic.consume'{queue = Queue,
                                                     no_ack = true}, self()),
    {ok, #state{domain_module=DomainModule, topics=Topics}}.

handle_call(Msg, From, State) ->
    lager:info("unexpected handle_call(~p, ~p, ~p) -> {reply, ok, ~p}",[Msg,From,State,State]),
    {reply, ok, State}.

handle_cast(Msg, State) ->
    lager:info("unexpected handle_cast(~p, ~p) -> {noreply, ~p}",[Msg,State,State]),
    {noreply, State}.

handle_info(#'basic.consume_ok'{}, State) ->
    lager:info("basic.consume_ok"),
    {noreply, State};
handle_info({#'basic.deliver'{routing_key = RoutingKey}, #amqp_msg{payload=Body}}, State) ->
    lager:info("basic.deliver  RoutingKey: ~p  Body: ~p", [RoutingKey, Body]),
    Module = State#state.domain_module,
    Module:handle_command_msg(Body),
    {noreply, State};
handle_info(Info, State) ->
    lager:warning("others  Info: ~p", [Info]),
    {noreply, State}.

terminate(Reason, State) ->
    lager:info("terminate(~p, ~p) -> ok",[Reason,State]),
    ok.

code_change(OldVsn, State, Extra) ->
    lager:info("unexpected code_change(~p, ~p, ~p) -> {ok, ~p}",[OldVsn,State,Extra,State]),
    {ok, State}.

create_queue(Host, Topics) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = Host}),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Channel, #'exchange.declare'{exchange = exchange(),
                                                   type = <<"topic">>}),
    #'queue.declare_ok'{queue=Queue} = amqp_channel:call(Channel, #'queue.declare'{exclusive = true}),
    lists:map(fun(BindingKey) ->
                      amqp_channel:call(Channel, #'queue.bind'{exchange = exchange(),
                                                               routing_key = BindingKey,
                                                               queue = Queue})
              end,
              Topics),
    {Connection, Channel, Queue}.

