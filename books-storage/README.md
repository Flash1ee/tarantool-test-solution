# Tarantool key-value storage
# О приложении  
Данное приложение представляет key-value хранилище и API для него.
Хранилище предназначено для хранения книг. Книги в хранилище описываются способом, представленным ниже:  
```
{
    "key": "string",
    "value": "[SOME ARBITRARY JSON]"
}
```  
# Настройка и запуск  
## Вариант 1  
Приложение развёрнуто на сервере Digital Ocean по ссылке [flashie.me:8081/](flashie.me:8081/)  
## Вариант 2  
Склонировать репозиторий 
```
git clone https://github.com/Flash1ee/tarantool-test-solution.git && cd tarantool-test-solution/books-storage
 
```  
Установить [Tarantool](https://www.tarantool.io/ru/) и [Tarantool Cartridge](https://github.com/tarantool/cartridge-cli#installation)  
Выполнить   
```
cartridge build
cartridge start
```
После этого, в веб-интерфейсе нужно перейти по адресу http://localhost:8081   для дальнейшей настройки кластера.
1. Нажмите кнопку `Configure` на `router`
2. Установите флажок напротив роли `api`
3. Нажмите кнопку `Create replica set`  
4. Нажмите кнопку `Configure` на `s1-master`
5. Установите флажок напротив роли `storage`
6. Нажмите кнопку `Create replica set` 
7. Нажмем кнопку `Bootstrap vshard` на закладке `Cluster` в веб-интерфейсе 
8. Кластер готов к работе! 

## Вариант 3   
Запуск в докер контейнере.  
- Склонировать репозиторий  
- Установить `make`
- Установить `docker`
- В папке `books-storage` выполнить `make docker` для сборки docker image
- Выполнить `make run` для запуска докера
- Перейти на http://localhost:8081 и повторить описанные в 2 варианте действия.  
- После завершения использования ввести `make stop` для остановки контейнера

# Использование  
API поддерживает запросы четырёх типов:  
```
- POST /kv body: {key: "some_key", "value": {SOME ARBITRARY JSON}} 
- PUT kv/{id} body: {"value": {SOME ARBITRARY JSON}} 
- GET kv/{id} 
- DELETE kv/{id} 
```  
- `POST` возвращает 409 если ключ уже существует, 
- `POST`, `PUT` возвращают 400 если боди некорректное 
- `PUT`, `GET`, `DELETE` возвращает 404 если такого ключа нет  
- все операции логируются

Результаты обработки запросов (и сами запросы) можно увидеть в консоли, в которой была введена команда `cartridge start`.  
Если запущен докер, то подключиться к нему через ```exec```  

Для работы с хранилищем воспользуемся [curl]("https://ru.wikipedia.org/wiki/CURL")  

## Добавить книжку в хранилище
Воспользуемся командой  
```
curl -X POST -v -H "Content-Type: application/json" -d '{"key":"1", "value": {"name": "War and peace", "author": "Leo Tolstoy", "year": 1869}}' http://localhost:8081/kv
```
Если всё прошло успешно, не допущено ошибок в запросе, то получим сообщение  
```
{"info":"Successfully created"}
```  
Повторное добавление книги с тем же ключом является ошибочной ситуацией, в результате получим.  
```
{"info":"Book already exist"}
```
## Получить книжку из хранилища
Для того чтобы получить книжку с key = 1 в формате json, воспользуемся командой:  
```
curl -X GET -v http://localhost:8081/kv/1
```
Получим  
```
{"key":"5","value":{"year":1869,"name":"War and peace","author":"Leo Tolstoy"}}
```  
Если бы ключ не существовал, то получили бы  
```
{"info":"Book not found"}
```
## Изменить информацию о книжке  
Для того чтобы изменить информацию о книжке с key = 1, воспользуемся командой:  
```
curl -X PUT -v -H "Content-Type: application/json" -d '{"value": {"name":"War and peace","author":"Tolstoy", "year": 1869}}' http://localhost:8081/kv/1
```  
Получим сообщение
```  
{"year":1869,"name":"War and peace","author":"Tolstoy"}  
```
Проверим изменения через GET запрос  
```
curl -X GET -v http://localhost:8081/kv/1
```  
Получим  
```
{"key":"1","value":{"year":1869,"name":"War and peace","author":"Tolstoy"}}  
```
Если тело некорректно, то выведется сообщение об ошибке.  
Например,  
```
curl -X PUT -v -H "Content-Type: application/json" -d '{"value": {"name":"War and peace","author":"Tolstoy", year: 1869}}' http://localhost:8081/kv/1
```
Результат  
```
{"info":"Incorrect body in request"}  
```
## Удалить книжку  
Для того чтобы удалить книжку с key = 1, воспользуемся командой:
```
curl -X DELETE -v http://localhost:8081/kv/1
```
Результат  
```
{"info":"Deleted"}
```
Проверим через GET запрос  
```
curl -X GET -v http://localhost:8081/kv/1
```
Получим
```
{"info":"Book not found"}
```
