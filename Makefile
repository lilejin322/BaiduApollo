clean:
	rm -rf ./data/log/ && rm -f cyber_recorder.* && rm -f sim_control_main.*

cleanAll:
	rm -rf ./data/log/ && rm -f cyber_recorder.* && rm -f sim_control_main.* && rm -f records/*

run:
	./docker/scripts/dev_start.sh -l && ./docker/scripts/dev_into.sh