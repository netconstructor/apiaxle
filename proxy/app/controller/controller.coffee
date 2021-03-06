{ Controller } = require "apiaxle.base"
{ ApiUnknown, ApiKeyError } = require "../../lib/error"

class exports.ApiaxleController extends Controller
  simpleBodyParser: ( req, res, next ) ->
    req.body = ""

    # add a body for PUTs and POSTs
    return next() if req.method in [ "HEAD", "GET" ]

    req.on "data", ( c ) -> req.body += c
    req.on "end", next

  subdomain: ( req, res, next ) ->
    # if we're called from a subdomain then let req know
    if parts = /^(.+?)\.api\./.exec req.headers.host
      req.subdomain = parts[1]

    return next()

  api: ( req, res, next ) =>
    # no subdomain means no api
    if not req.subdomain
      return next new ApiUnknown "No api specified (via subdomain)"

    @app.model( "api" ).find req.subdomain, ( err, api ) ->
      return next err if err

      if not api?
        # no api found
        return next new ApiUnknown "'#{ req.subdomain }' is not known to us."

      req.api = api
      return next()

  authenticateWithKey: ( key, req, next ) ->
    @app.model( "apiKey" ).find key, ( err, keyDetails ) ->
      return next err if err

      # check the key is for this api
      if keyDetails?.forApi isnt req.subdomain
        return next new ApiKeyError "'#{ key }' is not a valid key for '#{ req.subdomain }'"

      keyDetails.key = key
      req.apiKey = keyDetails

      return next()

  apiKey: ( req, res, next ) =>
    key = ( req.query.apiaxle_key or req.query.api_key )

    if not key
      return next new ApiKeyError "No api_key specified."

    @authenticateWithKey( key, req, next )
