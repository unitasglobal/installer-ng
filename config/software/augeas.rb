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

name 'augeas'
default_version '1.4.0'

source url: "http://download.augeas.net/augeas-#{version}.tar.gz"

version '1.4.0' do
  source md5: 'a2536a9c3d744dc09d234228fe4b0c93'
end

dependency 'libxml2'
dependency 'readline'

relative_path "augeas-#{version}"

license 'LGPL-2.1'
license_file 'COPYING'
skip_transitive_dependency_licensing true

build do
  env = with_standard_compiler_flags(with_embedded_path)

  command './configure' \
          ' --enable-static=no' \
          ' --without-selinux' \
          " --prefix=#{install_dir}/embedded", env: env

  make "-j #{workers}", env: env
  make "-j #{workers} install", env: env

end

