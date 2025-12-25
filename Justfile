build:
	xcodebuild -project CircuitPro.xcodeproj

run:
	xcodebuild -project CircuitPro.xcodeproj -scheme CircuitPro

clean:
	xcodebuild -project CircuitPro.xcodeproj clean

clean-build-folder:
	rm -rf build
