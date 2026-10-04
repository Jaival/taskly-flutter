# Switches the Runner target's Release configuration to manual signing.
#
#   ruby tool/ci/sign_xcode_target.rb <project.xcodeproj> <team> <profile> <identity>
#
# Run by apple_signing.sh on the release runner. The checked-in projects use
# automatic signing with no team, so anyone can build them on their own Mac.
# These settings are on the target, which beats any .xcconfig, and setting
# them on the xcodebuild command line would apply them to every Swift package
# too, which can't take a provisioning profile.
require 'xcodeproj'

path, team, profile, identity = ARGV
abort "usage: #{$PROGRAM_NAME} <project> <team> <profile> <identity>" unless identity

project = Xcodeproj::Project.open(path)
target = project.targets.find { |t| t.name == 'Runner' } or abort 'No Runner target'
config = target.build_configurations.find { |c| c.name == 'Release' } or abort 'No Release configuration'

settings = config.build_settings
settings['CODE_SIGN_STYLE'] = 'Manual'
settings['DEVELOPMENT_TEAM'] = team
settings['PROVISIONING_PROFILE_SPECIFIER'] = profile
settings['CODE_SIGN_IDENTITY'] = identity
project.save
