const Realm = require('realm');

let enterprise_token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJOb3RpZmllciI6dHJ1ZSwiU3luYyI6dHJ1ZSwiaWF0IjoxNDkyNjExMzEzfQ.Yb+o622ZYLKCQ0kTEDpBm6FsG68X9nj+OCdD4dT1G5W10fjhsTdUJiR1uYBilZPqgZEmIdDgd59rDpEjnqDhBCjTzpbsMVBGQrHj3B5eW4oGvxDkdqjR/fjwc5+zH3BeXMd9UAj13bLrxLsM0/g1FXIjmXCOK7YBrL0kKYAI2IVjqAGsI8zThhmbqxDvBeD8TVPc+brBZvXXHPO63ierJevjtZRz7mg/oV+B13gXXIxy2jlnevqFyBVRF6cd3bJmIpLUXHecQXqDGDeLaVlo2NDcnxl5OoVBN1QUSxptgQc+FIq+5qtxZXHooIJUpKQwtD2mBkJ+HBpxWbQR2C90UA==";

Realm.Sync.setFeatureToken(enterprise_token);

Realm.Sync.User.login('http://localhost:9080', 'realm-admin', '').then(user => {
   Realm.open({
       sync: {
           user: user,
           url:  'realm://localhost:9080/TeamworkPS-CommonRealm'
       },
       schema: [],
   }).then(realm => {
       console.log('Done');
   });
});

