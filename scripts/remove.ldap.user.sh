#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

source /etc/parallelcluster/cfnconfig

ldap_home="/home/efnobody"
ldap_pass="${ldap_home}/.ldappasswd"

USERNAME=$1

ldapdelete -x -W -D "cn=ldapadmin,dc=${stack_name},dc=internal" -y "${ldap_pass}" "uid=${USERNAME},ou=Users,dc=${stack_name},dc=internal"
#sudo chown -R root:root "/home/${USERNAME}"
#sudo mv /home/${USERNAME} "/home/${USERNAME}.$(date '+%Y-%m-%d-%H-%M-%S').BAK"