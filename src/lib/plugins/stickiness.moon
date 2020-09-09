-- Stickiness
-- This plugin tries to send the same requester to the same backend each time by
-- saving which backend they were sent to last in a cookie.

url = require 'socket.url'
base64 = require 'base64'

M = {}

M.get_cookie = (request, settings) ->

    -- get the sticky session cookie
    raw = request.cookies[settings.COOKIE]
    if raw != nil
        ok, cookie = pcall(base64.decode, raw)
        ngx.log(ngx.WARN, "Error decoding cookie: #{raw}")
        if ok
            return cookie
        return nil
    else
        return nil

M.set_cookie = (request, server, frontend, settings) ->

    -- encode cookie
    name = settings.COOKIE
    value = base64.encode(server)
    path = M.extract_path(frontend) -- extract path from frontend URL
    cookie = "#{url.escape(name)}=#{url.escape(value)}; Path=#{path}; HttpOnly; Secure"

    -- set the sticky session cookie
    ngx.log(ngx.DEBUG, "Setting sticky server: #{server} (Path=#{path})")
    ngx.header['Set-Cookie'] = cookie -- manually set response header

M.clear_cookie = (request, settings) ->

    -- delete the sticky session cookie
    request.cookies[settings.COOKIE] = nil

M.balance = (request, session, settings) ->

    -- if a sticky server is set, iterate servers until we find the matching one
    sticky_server = M.get_cookie(request, settings)
    if sticky_server != nil

        for server in *session.servers
            if sticky_server == M.extract_domain(server.address)
                return server

        ngx.log(ngx.WARN, "Server not found matching address: #{sticky_server}")

        -- cookie might be bad, clear it
        M.clear_cookie(request, settings)

    return session['servers']

M.post = (request, session, settings) ->

    -- get existing session cookie
    sticky_server = M.get_cookie(request, settings)

    -- set new sticky session cookie if changed
    if session.server != nil
        current_server = M.extract_domain(session.server)
        if sticky_server != current_server
            M.set_cookie(request, current_server, session.frontend, settings)

M.extract_domain = (url) ->
    if not string.match(url, '/')
        return url
    else
        location_index = string.find(url,'/')
        domain = string.sub(url, 1, (location_index - 1))
        return domain

M.extract_path = (url) ->
    i = string.find(url, '/')
    if i != nil
        string.sub(url, i)
    else
        return '/'

return M
