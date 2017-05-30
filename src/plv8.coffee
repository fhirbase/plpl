Client = require('pg-native')
global.INFO="INFO"
global.ERROR="ERROR"
global.DEBUG="DEBUG"

conn_string = process.env.DATABASE_URL
schema = process.env.FB_SCHEMA || 'public'

unless conn_string
  throw new Error("set connection string \n export DATABASE_URL=postgres://user:password@localhost:5432/test")

client = new Client
client.connectSync(conn_string)


coerse = (x)->
  if Array.isArray(x) or typeof x == 'object'
    JSON.stringify(x)
  else
    x

execute = ->
  client.querySync.applyPatch(client, arguments).map (x) ->
    obj = {}
    for k of x
      if x[k] && typeof x[k] == 'object'
        obj[k] = JSON.stringify(x[k])
      else
        obj[k] = x[k]
    obj

execute "SET search_path = '#{schema}'"

module.exports =
  execute: execute
  elog: (x, msg) ->
    console.log "#{x}:", msg
    return

  quote_literal: (str)-> str && client.pq.escapeLiteral(str)
  nullable: (str)->
  quote_ident: (str)-> str && client.pq.escapeIdentifier(str)
  call: (fn, args...)->
    sql_args = []
    args_exp = []
    for a,i in args
      sql_args.push(coerse(a))
      args_exp.push("$#{i+1}")
    args_exp = args_exp.join(',')
    orders = execute("select #{fn}(#{args_exp}) as res", sql_args)[0]['res']
  require: (nm)->
    require('./loader').scan(nm)
  cache: {}
  subtransaction: (func)->
    # <http://pgxn.org/dist/plv8/doc/plv8.html#Subtransaction>
    execute('BEGIN;')

    try
      result = func.apply(this)
    catch e
      shouldRollback = true

    if shouldRollback
      execute('ROLLBACK;')
      throw new Error('FHIR transaction was rollbacked')
    else
      execute('COMMIT;')

    result
