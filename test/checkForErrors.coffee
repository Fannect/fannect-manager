should = require "should"
Browser = require "zombie"

module.exports = exports = (page, url, done) ->
   Browser.visit url, (e, browser) ->
      browser.success.should.be.true
      browser.errors.length.should.equal(0)
      browser.close()
      done()