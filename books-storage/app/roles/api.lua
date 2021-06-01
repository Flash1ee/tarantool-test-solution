local cartridge = require('cartridge')
local errors = require('errors')
local log = require('log')
local json = require('json')

local err_vshard_router = errors.new_class("Vshard routing error")
local err_httpd = errors.new_class("httpd error")

local function json_response(req, json, status) 
    local resp = req:render({json = json})
    resp.status = status
    return resp
end

local function internal_error_response(req, error)
    local resp = json_response(req, {
        info = "Internal error",
        error = error
    }, 500)
    return resp
end

local function book_not_found_response(req)
    local resp = json_response(req, {
        info = "Book not found"
    }, 404)
    return resp
end

local function book_conflict_response(req)
    local resp = json_response(req, {
        info = "Book already exist"
    }, 409)
    return resp
end

local function book_incorrect_body_response(req, book)
    log.info("Incorrect body %s", book)
    local resp = json_response(req, {
        info = "Incorrect body in request"
    }, 400)
    return resp
end


local function storage_error_response(req, error)
    if error.err == "Book already exist" then
        return book_conflict_response(req)
    elseif error.err == "Book not found" then
        return book_not_found_response(req)
    elseif error.err == "Incorrect body" then
        return book_incorrect_body_response(req, nil)
    else
        return internal_error_response(req, error)
    end
end

local function http_book_add(req)
    local status, book = pcall(req.json, req)
    if status == false then
        return book_incorrect_body_response(req, book)
    end

    if type(book) ~= 'table' or type(book.value) ~= 'table' then
        return book_incorrect_body_response(req, json.encode(book))
    end

    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id(book.key)
    book.bucket_id = bucket_id

    local resp, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'write',
        'book_add',
        {book}
    )

    if error then
        return internal_error_response(req, error)
    end
    if resp.error ~= nil then
        return storage_error_response(req, resp.error)
    end
    return json_response(req, {info = "Successfully created"}, 201)
end

local function http_book_update(req)
    local book_id = tonumber(req:stash('id'))
    if book_id == nil then 
        return internal_error_response(req)
    end

    local status, data = pcall(req.json, req)
    if status == false then
        return book_incorrect_body_response(req, data)
    end
    
    local changes = data.value
    if type(changes) ~= 'table' then 
        return book_incorrect_body_response(req, json.encode(data))
    end

    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id(book_id)
    
    local resp, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'read',
        'book_update',
        {book_id, changes}
    )

    if error then
        return internal_error_response(req,error)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end
    
    return json_response(req, resp.book, 200)
end

local function http_book_get(req)
    local book_id = tonumber(req:stash('id'))
    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id(book_id)

    local resp, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'read',
        'book_get',
        {book_id}
    )

    if error then
        return internal_error_response(req, error)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end

    return json_response(req, resp.book, 200)
end

local function http_book_delete(req)
    local key = tonumber(req:stash('id'))
    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id(key)


    local resp, error = err_vshard_router:pcall(
        router.call,
        router,
        bucket_id,
        'write',
        'book_delete',
        {key}
    )

    if error then
        return internal_error_response(req, error)
    end
    if resp.error then
        return storage_error_response(req, resp.error)
    end

    return json_response(req, {info = "Deleted"}, 200)
end

local function init(opts)
    if opts.is_master then
        box.schema.user.grant('guest',
            'read,write',
            'universe',
            nil, { if_not_exists = true }
        )
    end

    local httpd = cartridge.service_get('httpd')

    if not httpd then
        return nil, err_httpd:new("not found")
    end

    log.info("Starting httpd")

    httpd:route(
        { path = '/kv', method = 'POST', public = true },
        http_book_add
    )
    httpd:route(
        { path = '/kv/:id', method = 'GET', public = true },
        http_book_get
    )
    httpd:route(
        { path = '/kv/:id', method = 'PUT', public = true },
        http_book_update
    )
    httpd:route(
        {path = '/kv/:id', method = 'DELETE', public = true},
        http_book_delete
    )

    log.info("Created httpd")
    return true
end

return {
    role_name = 'api',
    init = init,
    
    dependencies = {
        'cartridge.roles.vshard-router'
    }
}