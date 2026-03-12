APP = windowneon.app
SIGN_ID = Developer ID Application: Steven Vezeau (TH2XSQ2EQ6)
BUNDLE_ID = com.windovvsill.windowneon

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/windowneon $(APP)/Contents/MacOS/
	cp Info.plist $(APP)/Contents/
	codesign --force --options runtime --sign "$(SIGN_ID)" $(APP)

notarize: app
	ditto -c -k --keepParent $(APP) windowneon.zip
	xcrun notarytool submit windowneon.zip \
		--keychain-profile "notarytool-profile" \
		--wait
	xcrun stapler staple $(APP)
	rm windowneon.zip

clean:
	rm -rf $(APP) .build windowneon.zip
