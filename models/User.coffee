mongoose = require "mongoose"
crypt = require "../utils/crypt"

Email = mongoose.SchemaTypes.Email
Url = mongoose.SchemaTypes.Url

userSchema = mongoose.Schema
   email: { type: Email, index: { unique: true }, lowercase: true, trim: true }
   password: { type: String, required: true }
   first_name: { type: String, required: true }
   last_name: { type: String, required: true }
   profile_image_url: { type: Url }
   created_on: { type: Date, default: Date.now }
   refresh_token: { type: String, required: true }
   reload_stream: String
   # team_profiles: [{ type: Schema.Types.ObjectId, ref: "TeamProfile" }]

module.exports = mongoose.model("User", userSchema)
