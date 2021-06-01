
local t = require('luatest')
local log = require('log')
local g = t.group('unit_storage_utils')
local helper = require('test.helper.unit')

require('test.helper.unit')
local storage = require('app.roles.storage')
local utils = storage.utils
local deepcopy = helper.shared.deepcopy

local s = { ["name"] = 'War and peace', ["author"] = 'Leo Tolstoy'}
local val = deepcopy(s)
local test_book = {
    key = 1,
    bucket_id = 1,
    value= "",
}

local test_book_no_shadow = deepcopy(test_book)
test_book_no_shadow.bucket_id = nil

test_book_no_shadow.value = val
test_book.value = val

g.test_sample = function()
    t.assert_equals(type(box.cfg), 'table')
end

g.test_book_get_not_found = function()
    local res = utils.book_get(1)
    res.error = res.error.err
    t.assert_equals(res, {book = nil, error = "Book not found"})
end

g.test_book_get_found = function()
    box.space.books:insert(box.space.books:frommap(test_book))
    t.assert_equals(utils.book_get(1), {book = test_book_no_shadow, error = nil})
end

g.test_book_add_ok = function()
    local to_insert = deepcopy(test_book)
    to_insert.value = val
    t.assert_equals(utils.book_add(to_insert), {ok = true})
    local from_space = box.space.books:get(1)

    t.assert_equals(from_space, box.space.books:frommap(to_insert))
end

g.test_book_add_conflict = function()
    box.space.books:insert(box.space.books:frommap(test_book))
    local res = utils.book_add(test_book)
    res.error = res.error.err
    t.assert_equals(res, {ok = false, error = "Book already exist"})
end

g.test_profile_update_ok = function()
    box.space.books:insert(box.space.books:frommap(test_book))

    local changes = {
        year = 1869,
        author = "Tolstoy Leo"
    }

    local book_upd = deepcopy(test_book)
    book_upd.value = changes

    t.assert_equals(utils.book_update(1, changes), {book = changes})
    t.assert_equals(box.space.books:get(1), box.space.books:frommap(book_upd))
end

g.test_book_update_not_found = function()
    local res = utils.book_update(1,{year = 2020})
    res.error = res.error.err
    t.assert_equals(res, {book = nil, error = res.error})
end

g.test_profile_delete_ok = function()
    box.space.books:insert(box.space.books:frommap(test_book))
    t.assert_equals(utils.book_delete(1), {ok = true})
    t.assert_equals(box.space.books:get(1), nil)
end

g.test_profile_delete_not_found = function()
    local res = utils.book_delete(1)
    res.error = res.error.err
    t.assert_equals(res, {ok = false, error = "Book not found"})
end


g.before_all(function()
    storage.init({is_master = true})
end)

g.before_each(function ()
    box.space.books:truncate()
end)