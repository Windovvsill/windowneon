APP = windowneon.app

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/windowneon $(APP)/Contents/MacOS/
	cp Info.plist $(APP)/Contents/
	codesign --force --deep --sign - $(APP)

clean:
	rm -rf $(APP) .build
