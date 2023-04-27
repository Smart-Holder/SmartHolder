
const req = require('somes/request').default;

async function matic() {
	let {data} = await req.get('https://gpoly.blockscan.com/gasapi.ashx?apikey=key&method=gasoracle');
	// {
	// 	"LastBlock": "42009802",
	// 	"SafeGasPrice": "503.4",
	// 	"ProposeGasPrice": "536.3",
	// 	"FastGasPrice": "540.3",
	// 	"suggestBaseFee": "502.349930113",
	// 	"gasUsedRatio": "0.7663592,0.789767766666667,0.839163843493171,0.732857252881441,0.654532866188378",
	// 	"UsdPrice": "1.007"
	// }
	let {ProposeGasPrice: gasPrice,FastGasPrice} = JSON.parse(data + '').result;

	return Number(gasPrice) * 1000000000;
}

module.exports = {matic}

if (require.main === module) {
	const [_,__,network] = process.argv[2];
	(async function() {
		if (network == 'matic') {
			console.log(await matic());
		}
	})();
}