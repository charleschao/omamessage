.PHONY: validate test

test:
	node scripts/test-model.js

validate: test
	omarchy plugin validate .
	@if [ -z "$$OMARCHY_PATH" ]; then \
	  echo "OMARCHY_PATH unset — skipped qmllint"; \
	elif [ -x /usr/lib/qt6/bin/qmllint ]; then \
	  /usr/lib/qt6/bin/qmllint -I "$$OMARCHY_PATH/shell" BarWidget.qml Panel.qml; \
	else \
	  qmllint -I "$$OMARCHY_PATH/shell" BarWidget.qml Panel.qml; \
	fi
