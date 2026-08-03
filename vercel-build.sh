#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
export PATH="$PATH:$(pwd)/_flutter/bin"

flutter pub get
flutter build web --release
