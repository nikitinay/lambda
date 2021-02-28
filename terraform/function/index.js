const https = require('https');
exports.handler = async (event) => {
    let dataString = '';
    
    const response = await new Promise((resolve, reject) => {
        const req = https.get("https://blockchain.info/latestblock", function(res) {
          res.on('data', chunk => {
            dataString += chunk;
          });
          res.on('end', () => {
            resolve({
                body: JSON.stringify(JSON.parse(dataString), null, 4)
            });
          });
        });
        
        req.on('error', (e) => {
          reject({
              statusCode: 500,
              body: 'Something went wrong!'
          });
        });
    });
    
    console.log(response);
};