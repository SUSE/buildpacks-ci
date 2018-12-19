require_relative 'dotnet_framework_extractor'

# NOTE: Adapted from https://github.com/cloudfoundry/buildpacks-ci/blob/develop/tasks/build-binary-new/dotnet_framework_extractor.rb
# Also, upstream seems to checkout from specific commits.. https://github.com/cloudfoundry/buildpacks-ci/commit/9619b445198ce39d355055fb664df4deeb77021d

if ARGV.length != 3
  puts "Usage: <stack> <dotnet_version> <build dir>"
  exit 1
end

stack = ARGV[0]
version = ARGV[1]
dotnet_dir = ARGV[2]

#version = ENV.fetch('DOTNET_VERSION')
#stack = ENV.fetch('STACK')
#dotnet_dir = ENV.fetch('BUILDDIR')

major, minor, patch = version.split('.')

remove_frameworks = major.to_i >= 2 && minor.to_i >= 1

framework_extractor = DotnetFrameworkExtractor.new(dotnet_dir, stack)
puts "Extracting dotnet-runtime"
framework_extractor.extract_runtime(remove_frameworks)

# NOTE: Check https://github.com/cloudfoundry/buildpacks-ci/commit/8b34b2ee0ee0c77ddae9b9ba6ff30b78298c7534
# There are only separate ASP.net packages for dotnet core 2+

# TODO: not all dotnet-sdk ship this.
if major.to_i >= 2
	puts "Extracting dotnet-aspnetcore"
	framework_extractor.extract_aspnetcore(remove_frameworks)
end
puts "Extracting dotnet-sdk"
Dir.chdir(dotnet_dir) do
	dir = Dir.tmpdir
	ext = 'tar.xz'
	temptar=File.join(dir, "dotnet-sdk.#{ext}")
	system('tar', 'Jcf', temptar, '.')
	sha      = Digest::SHA256.hexdigest(open(temptar).read)
	filename = "dotnet-sdk.#{version}.linux-amd64-#{stack}-#{sha[0..7]}.#{ext}"
	FileUtils.mv(temptar, File.join("..", filename))
end
