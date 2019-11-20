#!/bin/bash
set -e

pushd catapult

# Deploy SCF
export BACKEND=ekcp
export FORCE_CLEAN=true
export QUIET_OUTPUT=true
export TASK_SCRIPT="$PWD/proxy.sh"

echo "#!/bin/bash" > $TASK_SCRIPT
echo "make module-extra-brats-setup" >> $TASK_SCRIPT
chmod +x $TASK_SCRIPT
make scf-deploy module-extra-ingress module-extra-task
