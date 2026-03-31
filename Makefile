.PHONY: gen gen-watch format analyze test ci

gen:
	dart run build_runner build --delete-conflicting-outputs

gen-watch:
	dart run build_runner watch --delete-conflicting-outputs

format:
	dart format .

analyze:
	dart analyze --fatal-infos

test:
	flutter test

ci: format gen analyze test
