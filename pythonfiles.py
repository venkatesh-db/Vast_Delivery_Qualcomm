

import os
content = """#!/bin/bash
echo "=============================="
echo " VAST Admin Morning Checklist"
echo " $(date)"
echo "=============================="
findmnt -t nfs,nfs4 -o TARGET,SOURCE
df -h /mnt/client1
nfsstat -c 2>/dev/null | head -6
ss -tn dst :2049 | wc -l | xargs echo "NFS connections:"
echo "=============================="
"""
open('/usr/local/bin/morning_healthcheck.sh','w').write(content)
os.chmod('/usr/local/bin/morning_healthcheck.sh',0o755)
print("done")
