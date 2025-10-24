list-tools:
	@cat json/list_tools.json | swift run Server 2>/dev/null
http-list-tools:
	curl -v --header "Accept: application/json" -d @json/list_tools.json 127.0.0.1:8080/mcp
call-weather:
	@cat json/call_weather_tool.json | swift run Server 2>/dev/null
http-call-weather:
	curl -v --header "Accept: application/json" -d @json/call_weather_tool.json 127.0.0.1:8080/mcp
call-calculator:
	@cat json/call_calculator_tool.json | swift run Server 2>/dev/null
http-call-calculator:
	curl -v --header "Accept: application/json" -d @json/call_calculator_tool.json 127.0.0.1:8080/mcp
call-fxrate:
	@cat json/call_fxrate_tool.json | swift run Server 2>/dev/null
http-call-fxrate:
	curl -v --header "Accept: application/json" -d @json/call_fxrate_tool.json 127.0.0.1:8080/mcp
list-prompts:
	@cat json/list_prompts.json | swift run Server 2>/dev/null
get-prompt:
	@cat json/get_prompts.json | swift run Server 2>/dev/null
initialize:
	curl -v --header "Accept: application/json" -d @json/initialize.json 127.0.0.1:8080/mcp
build:
	swift build
test:
	swift test
clean:
	swift package clean
	rm -rf .build
format:
	swift format format --parallel --recursive --in-place ./Package.swift Examples/ Sources/ Tests/
docker-build:
	docker build -t mcp-examples-server -f Dockerfile ..
docker-run:
	docker run -it --rm mcp-examples-server
