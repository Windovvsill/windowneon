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
	cp .build/release/windowneon $(APP)/Contents/MacOS/
	cp Info.plist $(APP)/Contents/
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" $(APP)/Contents/Info.plist
	codesign --force --options runtime --sign "$(SIGN_ID)" $(APP)

notarize: app
	ditto -c -k --keepParent $(APP) windowneon.zip
	xcrun notarytool submit windowneon.zip \
		--keychain-profile "notarytool-profile" \
		--wait
	xcrun stapler staple $(APP)
	rm windowneon.zip

release: notarize
	mkdir -p $(RELEASES_DIR)
	ditto -c -k --keepParent $(APP) $(RELEASES_DIR)/windowneon-$(VERSION).zip
	$(SPARKLE_BIN)/generate_appcast \
		--download-url-prefix "https://github.com/Windovvsill/windowneon/releases/download/v$(VERSION)/" \
		--link "https://github.com/Windovvsill/windowneon" \
		$(RELEASES_DIR)
	cp $(RELEASES_DIR)/appcast.xml appcast.xml
	git add appcast.xml VERSION
	git commit -m "Release v$(VERSION)"
	git tag -a v$(VERSION) -m "v$(VERSION)"
	@echo ""
	@echo "Release v$(VERSION) ready. Next steps:"
	@echo "  1. git push && git push --tags"
	@echo "  2. Upload $(RELEASES_DIR)/windowneon-$(VERSION).zip to GitHub releases"

clean:
	rm -rf $(APP) .build windowneon.zip
