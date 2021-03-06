#
# Copyright 2012-2014 Chef Software, Inc.
# Copyright 2015 Scalr, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name "libpng"
default_version "1.6.29"

source url: "http://downloads.sourceforge.net/libpng/libpng-#{version}.tar.gz"

version "1.6.29" do
  source md5: "68553080685f812d1dd7a6b8215c37d8"
end

version "1.5.17" do
  source md5: "d2e27dbd8c6579d1582b3f128fd284b4"
end

version "1.5.13" do
  source md5: "9c5a584d4eb5fe40d0f1bc2090112c65"
end

dependency "zlib"

relative_path "libpng-#{version}"

license 'libpng'
license_file 'LICENSE'
skip_transitive_dependency_licensing true


build do
  env = with_standard_compiler_flags(with_embedded_path)

  command "./configure" \
          " --prefix=#{install_dir}/embedded" \
          ' --mandir=/tmp' \
          " --with-zlib-prefix=#{install_dir}/embedded", env: env

  make "-j #{workers}", env: env
  make "install", env: env

end
