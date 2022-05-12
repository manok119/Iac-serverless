"use strict"
const serverless =require("serverless-http")
const express = require("express");
const app = express();
const mysql = require('mysql');
const AWS = require("aws-sdk");

const credentials = new AWS.SharedIniFileCredentials({
  profile: "manok119",
});
const sns = new AWS.SNS({ credentials: credentials, region: "ap-northeast-2" });


app.use(express.json());

app.get("/status", (req, res) => res.json({ status: "ok", sns: sns }));
app.post("/send", (req, res) => {
  var connection = mysql.createConnection({
    // 공용 데이터 사용 d조
    host: "project3-db-for-individuals.cpajpop7ewnt.ap-northeast-2.rds.amazonaws.com",
    user: "dob_user_d-1",
    password: "project3d-1",
    database: "project3d",
  });
  connection.connect();

  connection.query(
    `
        SELECT
            BIN_TO_UUID(product_id) as product_id
            , name, price, stock, BIN_TO_UUID(factory_id), BIN_TO_UUID(ad_id)
        FROM product
        WHERE sku = '${req.body.MessageAttributeProductId}';
        `,
    function (error, results, fields) {
      if (error) throw error;
      if (results[0].stock > 0) {
        console.log(results);
        console.log("The stock is: ", results[0].stock);
        const sql = `
                UPDATE product
                SET stock = ${results[0].stock - 1}
                WHERE product_id = UUID_TO_BIN('${results[0].product_id}');
                `;
        console.log(sql);
        connection.query(sql, function (error, results2, fields) {
          if (error) throw error;
        });
        console.log("재고 감소 !!");
        return res.status(200).send({ message: "판매완료" });
      } else {
        console.log("재고 부족 상황!!");
        console.log(req.body);
        let now = new Date().toString();
        let email = `${req.body.message} \n \n This was sent: ${now}`;
        let params = {
          Message: email,
          MessageGroupId: req.body.MessageGroupId,
          MessageDeduplicationId: new Date().getTime().toString(),
          Subject: req.body.subject,
          MessageAttributes: {
            ProductId: {
              StringValue: req.body.MessageAttributeProductId,
              DataType: "String",
            },
            FactoryId: {
              StringValue: req.body.MessageAttributeFactoryId,
              DataType: "String",
            },
          },
        
          TopicArn: "arn:aws:sns:ap-northeast-2:694280818671:stock_empty"
        };

        sns.publish(params, function (err, data) {
          if (err) console.log(err, err.stack);
          else console.log(data);
          return res.status(200).send({ message: "재고부족, 제품 생산 요청!" });
        });
      }
    }
  );
});


module.exports.handler = serverless(app);