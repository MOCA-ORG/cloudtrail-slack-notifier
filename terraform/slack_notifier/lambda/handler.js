const AWS = require('aws-sdk')
const zlib = require('zlib')
const config = require('config')
const { IncomingWebhook } = require("@slack/webhook")

const s3 = new AWS.S3()
const filters = require('./filters').filters
const webhook = new IncomingWebhook(config.SLACK_WEBHOOK_URL)

function decodeKey(key) {
    return decodeURIComponent(key.replace(/\+/g, ' '))
}

function getObject(bucket, key) {
    return s3.getObject({ Bucket: bucket, Key: key }).promise()
}

function gunzip(data) {
    return new Promise((resolve, reject) => {
        zlib.gunzip(data, (err, result) => {
            if (err) reject(err)
            else resolve(result)
        })
    })
}

function notify(records) {
    return Promise.all(records.map(record => {
        for (const filter of Object.values(filters)) {
            const message = filter(record)
            if (message) {
                console.info(message)
                return webhook.send({text: message})
            }
        }
    }))
}

exports.handler = async (event) => {
    try {
        const bucket = event.Records[0].s3.bucket.name
        const key = decodeKey(event.Records[0].s3.object.key)
        const data = await getObject(bucket, key)
        const gzippedResult = await gunzip(data.Body)
        const result = JSON.parse(gzippedResult.toString())
        await notify(result.Records)
    } catch (err) {
        console.error(err)
    }
}
