#!/bin/bash

# enter the directory the script is in
cd "`dirname $0`"
prog="`basename $0`"

scheme="GitX"
product="GitX.app"
label="dev"
base_version="0.14"

artifact_prefix="${scheme}-${label}"
workspace="${scheme}.xcodeproj/project.xcworkspace"
debug_configuration="Debug"
release_configuration="Release"
agvtool="xcrun agvtool"

configuration=""
clean=""
pause=3
build_number=""

print_usage()
{
    echo "Usage: $prog [-c] -d|-r [-b {number}]"
    echo "Where   -c clean before building"
    echo "        -d build for Debug configuration"
    echo "        -r build for Release configuration"
    echo "        -b {number}  overrides project build number"
}

while getopts drchb: flag
    do
        case $flag in

            d)
		configuration="$debug_configuration"
                  ;;
            r)
		configuration="$release_configuration"
                 ;;
	    c)
		clean="clean"
		;;
	    h)
		print_usage
		exit
		;;
	    b)
		build_number="$OPTARG"
		;;
            ?)
		print_usage
                exit
                ;;
        esac
   done
shift $(( OPTIND - 1 ))  # shift past the last flag or argument

if [ -z "$configuration" ]; then
    echo "$prog: error: must specify -d or -r"
    print_usage
    exit 1
fi

if [[ "$configuration" == "$release_configuration" ]]
then
    if ! [[ "$build_number" =~ ^[0-9]+$ ]]
    then
	echo "$prog: error: $release_configuration configuration must specify -b {number} (got \"${build_number}\")"
	print_usage
	exit 1
    fi
fi

if [ -z "$build_number" ]
then
    echo "$prog: not setting build number"
else
    echo "$prog: setting build number to $build_number"
    $agvtool mvers -terse1
    $agvtool vers -terse
    marketing_version="${base_version}.${build_number} ${label}"
    build_version="${base_version}.${build_number}"
    $agvtool new-marketing-version "$marketing_version"
    $agvtool new-version -all "$build_version"
fi

if [ -z "$clean" ]
then
    echo "Building $scheme from $workspace for $configuration in ${pause}..."
else
    echo "Building $scheme (cleanly) from $workspace for $configuration in ${pause}..."
fi
sleep $pause

build_dir="`pwd`/build/${configuration}"
xcrun xcodebuild -scheme "$scheme" -workspace "$workspace" -configuration "$configuration" "$clean" build CONFIGURATION_BUILD_DIR="$build_dir"

if [[ "$configuration" == "$release_configuration" ]]
then
    ./sign.py --app "${build_dir}/${product}" -fr
    ./package.py --app "${build_dir}/${product}" -o "${build_dir}/${artifact_prefix}-${build_number}.dmg" -n "${scheme} ${build_version}"
fi
