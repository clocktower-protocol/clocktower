#!/bin/bash
cd ../
npx hardhat ignition deploy ignition/modules/ClockSubscribe.ts --network localhost

echo "Subscribe Contract deployed locally"

npx hardhat run scripts/deploy_clocktower.ts --network localhost

echo "Deployed script run for testing"
