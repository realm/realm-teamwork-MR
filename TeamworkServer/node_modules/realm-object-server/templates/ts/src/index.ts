import { BasicServer } from 'realm-object-server'
import * as path from 'path'

const server = new BasicServer()

server.start({
        dataPath: path.join(__dirname, '../data')
    })
    .then(() => {
        console.log(`Your server is started `, server.address)
    })
    .catch(err => {
        console.error(`There was an error starting your file`)
    })