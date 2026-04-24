.PHONY: gen gen-l10n gen-watch format analyze test build-android-debug build-android-release-arm64 ci

gen-l10n:
	flutter gen-l10n

gen: gen-l10n
	dart run build_runner build --delete-conflicting-outputs

gen-watch:
	dart run build_runner watch --delete-conflicting-outputs

format:
	dart format .

analyze:
	bash scripts/check_reward_accent.sh
	dart analyze --fatal-infos
	bash scripts/check_hardcoded_colors.sh

test:
	flutter test

build-android-debug:
	flutter build apk --debug --no-shrink

ci: format gen analyze test build-android-debug

build-android-release-arm64:
	flutter build apk --split-per-abi --target-platform android-arm64
