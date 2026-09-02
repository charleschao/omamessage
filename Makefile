.PHONY: validate

validate:
	omarchy plugin validate .
	@if [ -n "$$OMARCHY_PATH" ]; then \
	  qmllint -I "$$OMARCHY_PATH/shell" BarWidget.qml Panel.qml; \
	else \
	  echo "OMARCHY_PATH unset — skipped qmllint"; \
	fi
