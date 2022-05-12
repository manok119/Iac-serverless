'use strict'

const http = require('http');

exports.handler = function(event, context){

    let newevent = JSON.parse(event.Records[0].body)
    
    const msg = {
        "MessageGroupId": 'stock-arrival-group',
        "MessageAttributeProductId": 'CP-502101',
        "MessageAttributeProductCnt": 10,
        "MessageAttributeFactoryId": 'FF-500293',
        "MessageAttributeRequester": '장만옥',
        "CallbackUrl": 'http://factory.p3.api.codestates-devops.be:8080/api/manufactures'
    }

    console.log(JSON.stringify(msg));
    try{
        const result = PostCode(msg);
        console.log(result);

        return {
            statusCode: 200,
            headers: {'ContentType': 'application/json'},
            body: JSON.stringify(result),
        };
    } catch (error){
        console.log(error);
        return {
            statusCode: 400,
            body: error.message,
        };
    }
}

function PostCode(post_data){
    const post_options = {
        host: 'factory.p3.api.codestates-devops.be',
        port: '8080',
        path: '/api/manufactures',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        }
    };

    const post_req = http.request(post_options, function(res){
        res.setEncoding('utf8');
        res.on('data', function (chunk) {
            console.log('Respoonse: ' + chunk)
        });
    });

    post_req.write(JSON.stringify(post_data));
    post_req.end();
}