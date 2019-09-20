#!/bin/bash

set -e

export QUIET_OUTPUT=true
export BACKEND=ekcp
cd catapult

make recover

export TASK_SCRIPT="$PWD/clean.sh"
echo "#!/bin/bash" > $TASK_SCRIPT
echo "CF_STACK=$CF_STACK make scf-purge" >> $TASK_SCRIPT
echo "CF_STACK=cflinuxfs3 make scf-purge" >> $TASK_SCRIPT
chmod +x $TASK_SCRIPT
make module-extra-task
