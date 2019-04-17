include properties.mk

appName = `grep entry manifest.xml | sed 's/.*entry="\([^"]*\).*/\1/'`
devices = `grep 'iq:product id' manifest.xml | sed 's/.*iq:product id="\([^"]*\).*/\1/'`

build:
	$(SDK_HOME)/bin/monkeyc \
	-f ./monkey.jungle \
	-d $(DEVICE) \
	-o bin/$(appName).prg \
	-y $(PRIVATE_KEY) \
	-w \
	-r

buildall:
	@for device in $(devices); do \
		echo "-----"; \
		echo "Building for" $$device; \
		$(SDK_HOME)/bin/monkeyc \
		--jungles ./monkey.jungle \
		--device $$device \
		--output bin/$(appName)-$$device.prg \
		--private-key $(PRIVATE_KEY) \
		--warn \
		--release \
		--debug; \
	done

run: build
	@$(SDK_HOME)/bin/connectiq &
	$(SDK_HOME)/bin/monkeydo bin/$(appName).prg $(DEVICE)

deploy: build
	@cp bin/$(appName).prg $(DEPLOY)

package:
	@$(SDK_HOME)/bin/monkeyc \
	--jungles ./monkey.jungle \
	--package-app \
	--release \
	--output bin/$(appName).iq \
	--private-key $(PRIVATE_KEY) \
	--warn
