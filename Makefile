APP          = windowneon.app
SIGN_ID      = Developer ID Application: Steven Vezeau (TH2XSQ2EQ6)
BUNDLE_ID    = com.windovvsill.windowneon
VERSION      = $(shell cat VERSION)
RELEASES_DIR = releases
SPARKLE_BIN  = .build/artifacts/sparkle/Sparkle/bin

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Frameworks
	cp .build/release/windowneonApp $(APP)/Contents/MacOS/windowneon
	install_name_tool -add_rpath @executable_path/../Frameworks $(APP)/Contents/MacOS/windowneon
	cp Info.plist $(APP)/Contents/
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" $(APP)/Contents/Info.plist
	cp -R .build/arm64-apple-macosx/release/Sparkle.framework $(APP)/Contents/Frameworks/
	find $(APP)/Contents/Frameworks/Sparkle.framework -name .DS_Store -delete
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" \
		$(APP)/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" \
		$(APP)/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" \
		$(APP)/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" \
		$(APP)/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" \
		$(APP)/Contents/Frameworks/Sparkle.framework
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" $(APP)

notarize: app
	ditto -c -k --keepParent $(APP) windowneon.zip
	xcrun notarytool submit windowneon.zip \
		--keychain-profile "notarytool-profile" \
		--wait
	xcrun stapler staple $(APP)
	rm windowneon.zip

release: notarize
	mkdir -p $(RELEASES_DIR)
	ditto -c -k --keepParent --norsrc $(APP) $(RELEASES_DIR)/windowneon-$(VERSION).zip
	$(SPARKLE_BIN)/generate_appcast \
		--download-url-prefix "https://github.com/Windovvsill/windowneon/releases/download/v$(VERSION)/" \
		--link "https://github.com/Windovvsill/windowneon" \
		$(RELEASES_DIR)
	cp $(RELEASES_DIR)/appcast.xml appcast.xml
	git add appcast.xml VERSION
	git commit -m "Release v$(VERSION)"
	git tag -a v$(VERSION) -m "v$(VERSION)"
	git push && git push --tags
	gh release create v$(VERSION) \
		$(RELEASES_DIR)/windowneon-$(VERSION).zip \
		--title "v$(VERSION)" \
		--notes ""

bump:
	@old=$(shell cat VERSION); \
	major=$$(echo $$old | cut -d. -f1); \
	minor=$$(echo $$old | cut -d. -f2); \
	patch=$$(echo $$old | cut -d. -f3); \
	new=$$major.$$minor.$$((patch + 1)); \
	echo $$new > VERSION; \
	echo "$$old → $$new"

clean:
	rm -rf $(APP) .build windowneon.zip
