const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const auth = require("firebase-auth");
const serviceAccount = require("./serviceAccountKey.json");

require('dotenv').config();

serviceAccount.private_key = process.env.PRIVATE_KEY;

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

exports.createCustomToken = onRequest(async (request, response) => {
  const user = request.body;
  const uid = `kakao:${user.uid}`;
  const updateParams = {
    email: user.email,
    photoURL: user.photoURL,
    displayName: user.displayName,
  };

  try {
    await admin.auth().updateUser(uid, updateParams);
  } catch (error) {
    updateParams.uid = uid;
    await admin.auth().createUser(updateParams);
  }

  const token = await admin.auth().createCustomToken(uid);
  response.send(token);
});

