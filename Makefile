# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

.DEFAULT_GOAL := help

.PHONY: help docs test

help:		## display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# inspiration from Patrick Collins: https://github.com/smartcontractkit/foundry-starter-kit/blob/main/Makefile
# wip (don't use "all" yet)
all: clean remove install update build

clean: ## clean the repo
	forge clean

update: ## update rust, foundry and submodules
	rustup update && foundryup && forge update

formatsol: ## run prettier on src, test and scripts
	yarn run prettier

lintsol: ## run prettier and solhint
	yarn run lint

devnet: ## run development node
	anvil -f ${ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000 \
		-vvvv

gen-i: ## generate solidity interfaces from facet implementations
	forge script GenerateInterfaces \
		-s "run(string memory, string memory)" src/diamonds/nayms/interfaces/ 0.8.13 \
		--ffi

prep-build: ## prepare buld, generate LibGeneratedNaymsFacetHelpers
	node ./cli-tools/prep-build.js 

build: ## forge build
	forge build --names --sizes
b: build

bscript: ## build forge scripts
	forge build --root . --contracts script/

test: ## forge test local, alias t
	forge test
t: test

tt: ## forge test local -vv
	forge test -vv

ttt: ## forge test local -vvv
	forge test -vvv
	
tttt: ## forge test local -vvvv
	forge test -vvvv

test-goerli: ## test forking goerli with match test regex, i.e. `make test-goerli MT=testStartTokenSale`
	forge test -f ${ETH_GOERLI_RPC_URL} \
		--fork-block-number 7602168 \
		--mt $(MT) \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		-vvvv
tg:	test-goerli

test-mainnet: ## test forking mainnet with match test regex, i.e. `make test-mainnet MT=testStartTokenSale`
	forge test -f ${ETH_MAINNET_RPC_URL} \
		--fork-block-number 7602168 \
		--mt $(MT) \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		-vvvv
tm:	test-mainnet

gas: ## gas snapshot
	forge snapshot --check

gasforksnap: ## gas snapshot mainnet fork
	forge snapshot --snap .gas-snapshot \
		-f ${ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000

gasforkcheck: ## gas check mainnet fork
	forge snapshot --check \
		-f ${ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000 \
		--via-ir

gasforkdiff: ## gas snapshot diff mainnet fork
	forge snapshot --diff \
		-f ${ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000 \
		--via-ir

cov: ## coverage report -vvv
	forge coverage -vvv

coverage: ## coverage report (lcov), filtered for CI
	forge coverage -vvv --report lcov --via-ir && node ./cli-tools/filter-lcov.js

lcov: ## coverage report (lcov)
	forge coverage --report lcov --via-ir

lcov-fork: ## coverage report (lcov) for mainnet fork
	forge coverage --report lcov \
		-f ${ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000 \
		--via-ir

# solidity scripts
erc20: ## deploy test ERC20
	forge script DeployERC20 \
		-s "deploy(string memory _name, string memory _symbol, uint8 _decimals)" \
		${ERC20_NAME} ${ERC20_SYMBOL} ${ERC20_DECIMALS} \
		-vvvv

erc20-mainnet: ## deploy mock ERC20
	forge script DeployERC20 \
		-s "deploy(string memory _name, string memory _symbol, uint8 _decimals)" \
		${ERC20_NAME} ${ERC20_SYMBOL} ${ERC20_DECIMALS} \
		-f ${ETH_MAINNET_RPC_URL} \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--ffi \
		--broadcast \
		--verify --delay 30 --retries 10 \
		; node cli-tools/postproc-broadcasts.js

erc20-mainnet-sim: ## simulate deploy mock ERC20
	forge script DeployERC20 \
		-s "deploy(string memory _name, string memory _symbol, uint8 _decimals)" \
		${ERC20_NAME} ${ERC20_SYMBOL} ${ERC20_DECIMALS} \
		-f ${ETH_MAINNET_RPC_URL} \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		-vv \
		--ffi \
		; node cli-tools/postproc-broadcasts.js

# use the "@" to hide the command from your shell 
erc20g: ## deploy test ERC20 to Goerli
	@forge script DeployERC20 -s "deploy(string memory _name, string memory _symbol, uint8 _decimals)" \
		${ERC20_NAME} ${ERC20_SYMBOL} ${ERC20_DECIMALS} \
		-f ${ETH_GOERLI_RPC_URL} \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		--broadcast \
		--verify \
		-vvvv

# Deployment defaults
facetsToCutIn="[]"
newDiamond=false
initNewDiamond=false
facetAction=1
senderAddress=0x931c3aC09202650148Edb2316e97815f904CF4fa
deploymentSalt=0xdeffffffff

schedule-upgrade-goerli: ## schedule upgrade to goerli diamond, then upgrade
	@forge script SmartDeploy \
		-s "scheduleAndUpgradeDiamond()" \
		-f ${ETH_GOERLI_RPC_URL} \
		--chain-id 5 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		--private-key ${OWNER_ACCOUNT_KEY} \
		-vv \
		--ffi \
		--broadcast \
		--verify --delay 30 --retries 10 \
		; node cli-tools/postproc-broadcasts.js

deploy-goerli: ## smart deploy to goerli
	@forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory, bytes32)" ${newDiamond} ${initNewDiamond} ${facetAction} ${facetsToCutIn} ${deploymentSalt} \
		-f ${ETH_GOERLI_RPC_URL} \
		--chain-id 5 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--ffi \
		--broadcast \
		--verify --delay 30 --retries 10 \
		; node cli-tools/postproc-broadcasts.js

deploy-goerli-sim: ## simulate smart deploy to goerli
	forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory, bytes32)" ${newDiamond} ${initNewDiamond} ${facetAction} ${facetsToCutIn} ${deploymentSalt} \
		-f ${ETH_GOERLI_RPC_URL} \
		--chain-id 5 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		-vv \
		--ffi

deploy-sepolia: ## smart deploy to sepolia
	@forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory, bytes32)" ${newDiamond} ${initNewDiamond} ${facetAction} ${facetsToCutIn} ${deploymentSalt} \
		-f ${ETH_SEPOLIA_RPC_URL} \
		--chain-id 11155111 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--ffi \
		--broadcast \
		--verify --delay 30 --retries 10 \
		; node cli-tools/postproc-broadcasts.js

deploy-sepolia-sim: ## simulate smart deploy to sepolia
	forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory, bytes32)" ${newDiamond} ${initNewDiamond} ${facetAction} ${facetsToCutIn} ${deploymentSalt} \
		-f ${ETH_SEPOLIA_RPC_URL} \
		--chain-id 11155111 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		-vv \
		--ffi

deploy-mainnet: ## smart deploy to mainnet
	@forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory, bytes32)" ${newDiamond} ${initNewDiamond} ${facetAction} ${facetsToCutIn} ${deploymentSalt} \
		-f ${ETH_MAINNET_RPC_URL} \
		--chain-id 1 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--ffi \
		--broadcast \
		--verify --delay 30 --retries 10 \
		; node cli-tools/postproc-broadcasts.js

deploy-mainnet-sim: ## simulate deploy to mainnet
	@forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory, bytes32)" ${newDiamond} ${initNewDiamond} ${facetAction} ${facetsToCutIn} ${deploymentSalt} \
		-f ${ETH_MAINNET_RPC_URL} \
		--chain-id 1 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		-vv \
		--ffi 

anvil:	## run anvil with shared wallet
	anvil --host 0.0.0.0 --chain-id 31337 --accounts 20 -m ./nayms_mnemonic.txt --state anvil.json

anvil-debug:	## run anvil in debug mode with shared wallet
	RUST_LOG=backend,api,node,rpc=warn anvil --host 0.0.0.0 --chain-id 31337 -m ./nayms_mnemonic.txt  --state anvil.json

anvil-fork: ## fork goerli locally with anvil
	anvil -f ${ETH_GOERLI_RPC_URL}

anvil-deploy: ## smart deploy locally to anvil
	forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory, bytes32)" true true 0 ${facetsToCutIn} ${deploymentSalt} \
		-f http:\\127.0.0.1:8545 \
		--chain-id 31337 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--ffi \
		--broadcast

anvil-upgrade: ## smart deploy locally to anvil
	forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory, bytes32)" false false 1 ${facetsToCutIn} ${deploymentSalt}\
		-f http:\\127.0.0.1:8545 \
		--chain-id 31337 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--ffi \
		--broadcast

anvil-replace-dc: ## Replace diamondCut() with the 2-phase diamondCut() on anvil
	forge script ReplaceDiamondCut \
		-f http:\\127.0.0.1:8545 \
		--chain-id 31337 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--ffi \
		--broadcast

anvil-gtoken:	## deploy dummy erc20 token to local node
	forge script DeployERC20 \
		-s "deploy(string memory, string memory, uint8)" "GToken" "GTK" 18 \
		-f http:\\127.0.0.1:8545 \
		--chain-id 31337 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--ffi \
		--broadcast

anvil-add-supported-external-token: ## Add a supported external token (anvil)
	@forge script AddSupportedExternalToken \
		-s "addSupportedExternalToken(address naymsDiamondAddress, address externalToken)" ${naymsDiamondAddress} ${externalToken} \
		-f http:\\127.0.0.1:8545 \
		--chain-id 31337 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--broadcast

goerli-replace-ownership: ## Replace transferOwnership()
	forge script ReplaceOwnershipFacet \
		-f ${ETH_GOERLI_RPC_URL} \
		--chain-id 5 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--ffi \
		--broadcast \
		--verify --delay 30 --retries 10

create-entity: ## create an entity on the Nayms platform (using some default values, on anvil)
	forge script CreateEntity \
		-s "createAnEntity(address)" ${naymsDiamondAddress} \
		-f http:\\127.0.0.1:8545 \
		--chain-id 31337 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--broadcast

add-supported-external-token: ## Add a supported external token (goerli)
	@forge script AddSupportedExternalToken \
		-s "addSupportedExternalToken(address naymsDiamondAddress, address externalToken)" ${naymsDiamondAddress} ${externalToken} \
		-f ${ETH_GOERLI_RPC_URL} \
		--chain-id 5 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--broadcast

update-commissions: ## update trading and premium commissions
	forge script UpdateCommissions \
		-s "tradingAndPremium(address)" ${naymsDiamondAddress} \
		-f ${ETH_GOERLI_RPC_URL} \
		--chain-id 5 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vv \
		--broadcast

subgraph: ## generate diamond ABI for the subgraph
	yarn subgraph:abi

docs: ## generate docs from natspec comments
	yarn docgen

slither:	## run slither static analysis
	slither src/diamonds/nayms --exclude solc-version,assembly-usage,naming-convention,low-level-calls --ignore-compile

upgrade-hash-goerli: ## generate upgrade hash
	@forge script SmartDeploy \
		-s "hash(bool, uint8, string[] memory, bytes32)" false 1 "[]" ${deploymentSalt} \
		--fork-url ${ETH_GOERLI_RPC_URL} \
		--chain-id 5 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--ffi \
		--silent \
		--json \
		| jq --raw-output '.returns.upgradeHash.value, .returns.cut.value'

upgrade-hash-mainnet: ## generate upgrade hash
	@forge script SmartDeploy \
		-s "hash(bool, uint8, string[] memory, bytes32)" false 1 "[]" ${deploymentSalt} \
		--fork-url ${ETH_MAINNET_RPC_URL} \
		--chain-id 1 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--ffi \
		--silent \
		--json \
		| jq --raw-output '.returns.upgradeHash.value, .returns.cut.value'

upgrade-hash-anvil: ## generate upgrade hash
	forge script SmartDeploy \
		-s "hash(bool, uint8, string[] memory, bytes32)" ${newDiamond} ${facetAction} ${facetsToCutIn} ${deploymentSalt} \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		--ffi

verify-dry-run:	## dry run verify script, prints out commands to be executed
	node cli-tools/verify.js --dry-run

verify:	## verify contracts on chain (goerli)
	node cli-tools/verify.js


update-e: ## update
	forge script UpdateEntity \
		-f ${ETH_GOERLI_RPC_URL} \
		--chain-id 5 \
		--sender ${senderAddress} \
		--mnemonic-paths ./nayms_mnemonic.txt \
		--mnemonic-indexes 19 \
		-vvvv \
		--broadcast