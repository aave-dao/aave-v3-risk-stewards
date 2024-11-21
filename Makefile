# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

coverage :; forge coverage --report lcov && \
	lcov --remove ./lcov.info -o ./lcov.info.p \
	'tests/*' \
	'src/contracts/dependencies/*' \
	'src/contracts/examples/*' \
	'src/contracts/updates/*' \
	'scripts/*' \
	&& genhtml ./lcov.info.p -o report --branch-coverage \
	&& coverage=$$(awk -F '[<>]' '/headerCovTableEntryHi/{print $3}' ./report/index.html | sed 's/[^0-9.]//g' | head -n 1); \
	wget -O ./report/coverage.svg "https://img.shields.io/badge/coverage-$${coverage}%25-brightgreen"

# Build & test
build  :; forge build --sizes
test   :; forge test -vvv

# Utilities
download :; cast etherscan-source --chain ${chain} -d src/etherscan/${chain}_${address} ${address}
git-diff :
	@mkdir -p diffs
	@npx prettier ${before} ${after} --write
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md

# Deploy
deploy-ledger :; FOUNDRY_PROFILE=${chain} forge script $(if $(filter zksync,${chain}),--zksync) ${contract} --rpc-url ${chain} $(if ${dry},--sender 0x25F2226B597E8F9514B3F68F00f494cF4f286491 -vvvv, --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --verify -vvvv --slow --broadcast)
deploy-pk :; FOUNDRY_PROFILE=${chain} forge script $(if $(filter zksync,${chain}),--zksync) ${contract} --rpc-url ${chain} $(if ${dry},--sender 0x25F2226B597E8F9514B3F68F00f494cF4f286491 -vvvv, --private-key ${PRIVATE_KEY} --verify -vvvv --slow --broadcast)

run-script:; FOUNDRY_PROFILE=${network} forge script ${contract} --rpc-url ${network} --sig "run(bool, bool)" ${broadcast} ${generate_diff} -vv
