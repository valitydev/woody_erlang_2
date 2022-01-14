REBAR := $(shell which rebar3 2>/dev/null || which ./rebar3)

compile:
	$(REBAR) compile

test:
	$(REBAR) eunit
	$(REBAR) ct

xref:
	$(REBAR) xref

lint:
	$(REBAR) lint

check_format:
	$(REBAR) fmt -c

format:
	$(REBAR) fmt -w

clean:
	$(REBAR) clean
	$(REBAR) as test clean
	$(REBAR) as prod clean

distclean:
	rm -rf test/woody_test_thrift.?rl test/.rebar3
	rm -rfv _build

dialyze:
	$(REBAR) as test dialyzer

bench:
	$(REBAR) as test bench -m bench_woody_event_handler -n 1000
	$(REBAR) as test bench -m bench_woody_formatter -n 10
	erl -pa _build/test/lib/*/ebin _build/test/lib/woody/test -noshell \
		-s benchmark_memory_pressure run \
		-s erlang halt
