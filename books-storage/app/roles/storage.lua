local checks = require('checks')
local errors = require('errors')
local log = require('log')



local err_storage = errors.new_class("Storage error")

local function tuple_to_table(format, tuple)
    local map = {}
    for i, v in ipairs(format) do
        map[v.name] = tuple[i]
    end
    return map
end

local function init_space()
    local books = box.schema.space.create(
        'books',
        {
            format = {
                {'key', 'string'},
                {'bucket_id', 'unsigned'},
                {'value', 'any'},
            },

            if_not_exists = true,
        }
    )

    books:create_index('key', {
        parts = {'key'},
        if_not_exists = true,
    })

    books:create_index('bucket_id', {
        parts = {'bucket_id'},
        unique = false,
        if_not_exists = true,
    })
end

local function book_add(book)
    checks('table')

    local exist = box.space.books:get(book.key)
    if exist ~= nil then
        log.info("Book with id %d already exist", book.key)
        return {ok = false, error = err_storage:new("Book already exist")}
    end

    box.space.books:insert(box.space.books:frommap(book))

    return {ok = true, error = nil}
end

local function book_update(key, changes)
    checks('string', 'table')

    local exists = box.space.books:get(key)

    if exists == nil then
        log.info("Book with id %d not found", key)
        return {book = nil, error = err_storage:new("Book not found")}
    end

    exists = tuple_to_table(box.space.books:format(), exists)
    exists.value = changes

    box.space.books:replace(box.space.books:frommap(exists))

    changes.bucket_id = nil

    return {book = changes, error = nil}
end

local function book_get(id)
    checks('string')
    
    local book = box.space.books:get(id)
    if book == nil then
        log.info("Book with id %s not found", id)
        return {books = nil, error = err_storage:new("Book not found")}
    end

    book = tuple_to_table(box.space.books:format(), book)
    
    book.bucket_id = nil
    return {book = book, error = nil}
end

local function book_delete(key)
    checks('string')
    
    local exists = box.space.books:get(key)
    if exists == nil then
        log.info("Book with id %d not found", key)
        return {ok = false, error = err_storage:new("Book not found")}
    end
    exists = tuple_to_table(box.space.books:format(), exists)

    box.space.books:delete(key)
    return {ok = true, error = nil}
end

local function init(opts)
    if opts.is_master then
        init_space()

        box.schema.func.create('book_add', {if_not_exists = true})
        box.schema.func.create('book_get', {if_not_exists = true})
        box.schema.func.create('book_update', {if_not_exists = true})
        box.schema.func.create('book_delete', {if_not_exists = true})
    end

    rawset(_G, 'book_add', book_add)
    rawset(_G, 'book_get', book_get)
    rawset(_G, 'book_update', book_update)
    rawset(_G, 'book_delete', book_delete)

    return true
end

return {
    role_name = 'storage',
    init = init,
    utils = {
        book_add = book_add,
        book_update = book_update,
        book_get = book_get,
        book_delete = book_delete,
    },
    dependencies = {
        'cartridge.roles.vshard-storage'
    }
}