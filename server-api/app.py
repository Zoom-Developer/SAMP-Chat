from flask import Flask, request
from config import *
from vk_api.bot_longpoll import VkBotLongPoll, VkBotEventType
import pymysql, pymysql.cursors, uuid, vk_api, threading, time, random, io, requests, speech_recognition, pydub

attach_types = {"photo": "Фотография", "video": "Видео", "wall": "Репост", "sticker": "Стикер"}

vk = vk_api.VkApi(token=VK_TOKEN)
vk_api = vk.get_api()

conn = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASS, database=DB_NAME, cursorclass=pymysql.cursors.DictCursor)
cursor = conn.cursor()
cursor.execute("CREATE TABLE IF NOT EXISTS `users` (`id` int PRIMARY KEY AUTO_INCREMENT, `token` VARCHAR(255) UNIQUE, `rank` int, `name` VARCHAR(255), `vk` int, `reg_ip` VARCHAR(255), `login_ip` VARCHAR(255), `online` int, `x` int, `y` int, `server` VARCHAR(255), `ip` VARCHAR(255), `in_int` int)")
cursor.execute("CREATE TABLE IF NOT EXISTS `messages` (`id` INT PRIMARY KEY AUTO_INCREMENT , `text` TEXT , `user` VARCHAR(255), `name` VARCHAR(255), `type` VARCHAR(255), `ip` VARCHAR(255), `server` VARCHAR(255), `receiver` VARCHAR(255), `receiver_name` VARCHAR(255))")
cursor.execute("UPDATE `users` SET `online` = '0'")
conn.commit()
cursor.close()

app = Flask(__name__)

users_online = {}
vk_codes = {}

def sql_execute(command, commit=False):
    command = command.replace("'", '"')
    conn = pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASS, database=DB_NAME, cursorclass=pymysql.cursors.DictCursor)
    cursor = conn.cursor()
    cursor.execute(command)
    if commit: conn.commit()
    conn.close()
    return cursor

def get_user():
    cursor = sql_execute("SELECT * FROM `users` WHERE `token` = '%s'" % request.headers.get("Authorization"))
    user = cursor.fetchone()
    cursor.close()
    if user: 
        cursor = sql_execute("UPDATE `users` SET `login_ip` = '%s' WHERE `id` = '%s'" % (request.environ['REMOTE_ADDR'], user['id']), True)
        cursor.close()
    return user

def randomcode(length=10):
    valid_letters='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return ''.join((random.choice(valid_letters) for i in range(length)))

def recognize_url(url):
    with io.BytesIO() as source_file:
        source_file.write(requests.get(url).content)
        source_file.seek(0)
        ogg = pydub.AudioSegment.from_ogg(source_file)
        with io.BytesIO() as file:
            ogg.export(file, format="wav")
            file.seek(0)
            recognizer = speech_recognition.Recognizer()
            with speech_recognition.AudioFile(file) as audiofile:
                audio = recognizer.record(audiofile)
            try: return recognizer.recognize_google(audio, language="ru")
            except: return "Не распознано"

@app.route("/member", methods=["POST"])
def add_member():
    try: data = request.args
    except: return {"error": "Invalid body"}, 400
    if not data.get("name"): return {"error": "Invalid arguments"}, 400
    token = str(uuid.uuid4())
    cursor = sql_execute("INSERT INTO `users` (`token`, `reg_ip`, `name`, `rank`) VALUES ('%s', '%s', '%s', '0')" % (token, request.environ['REMOTE_ADDR'], data['name']), True)
    cursor.close()
    return {"id": cursor.lastrowid, "token": token}

@app.route("/member", methods=["PATCH"])
def set_nick():
    user = get_user()
    if not user: return {"error": "Invalid user"}, 401
    try: data = request.args
    except: return {"error": "Invalid body"}, 400
    if not data.get("name"): return {"error": "Invalid arguments"}, 400
    if len(data['name']) > 25: return {"error": "Max nick length - 15"}, 470
    cursor = sql_execute("UPDATE `users` SET `name` = '%s' WHERE `id` = '%s'" % (data['name'], user['id']), True)
    cursor.close()
    return {"name": data['name']}

@app.route("/member", methods=["GET"])
def member():
    user = get_user()
    if not user: return {"error": "Invalid user"}, 401
    return user

@app.route("/member/ping", methods=["POST"])
def ping():
    user = get_user()
    if not user: return {"error": "Invalid user"}, 401
    if user['rank'] < 1: return {"error": "Access denied"}, 403
    try: data = request.args
    except: return {"error": "Invalid body"}, 400
    if not data.get("online"): return {"error": "Invalid arguments"}, 400
    cursor = sql_execute("UPDATE `users` SET `online` = '%s', `x` = '%s', `y` = '%s', `server` = '%s', `ip` = '%s', `in_int` = '%s' WHERE `id` = '%s'" % (data['online'], data.get("x", 0), data.get("y", 0), data.get("server"), data.get("ip"), data.get("in_int", 0), user['id']), True)
    cursor.close()
    cursor = sql_execute("SELECT `name`, `server`, `id`, `online`, `ip`, `x`, `y` FROM `users` WHERE `rank` > 0")
    users = cursor.fetchall()
    cursor.close()
    users_online[user['id']] = time.time()
    threading.Thread(target=online_timer, args=(user['id'],)).start()
    return {"status": "Ok", "user": user, "users": users}

@app.route("/sms", methods=["POST"])
def send_sms():
    try: data = request.args
    except: return {"error": "Invalid body"}, 400
    if not data.get("text") or not data.get("receiver"): return {"error": "Invalid arguments"}, 400
    user = get_user()
    if not user: return {"error": "Invalid user"}, 401
    if user['rank'] < 1: return {"error": "Access denied"}, 403
    cursor = sql_execute("SELECT * FROM `users` WHERE `id` = '%s' and `online` > 0" % data['receiver'])
    receiver = cursor.fetchone()
    if not receiver:
        cursor.close()
        cursor = sql_execute("SELECT * FROM `users` WHERE `name` LIKE '%%%s%%' and `online` > 0" % data['receiver'])
        receiver = cursor.fetchone()
    if not receiver: 
        cursor.close()
        return {"error": "Invalid receiver"}, 470
    cursor = sql_execute("INSERT INTO `messages` (`text`, `user`, `name`, `receiver`, `receiver_name`, `type`) VALUES('%s', '%s', '%s', '%s', '%s', 'sms')" % (data['text'], user['id'], user['name'], receiver['id'], receiver['name']), True)
    cursor.close()
    return {"id": cursor.lastrowid, "text": data['text'], "receiver": {"id": receiver['id'], "name": receiver['name']}}

@app.route("/messages", methods=["POST"])
def send_message():
    try: data = request.args
    except: return {"error": "Invalid body"}, 400
    if not data.get("text") or not data.get("ip") or not data.get("server"): return {"error": "Invalid arguments"}, 400
    user = get_user()
    if not user: return {"error": "Invalid user"}, 401
    if user['rank'] < 1: return {"error": "Access denied"}, 403
    cursor = sql_execute("INSERT INTO `messages` (`text`, `user`, `name`, `type`, `ip`, `server`) VALUES('%s', '%s', '%s', '%s', '%s', '%s')" % (data['text'], user['id'], user['name'], "samp", data.get("ip"), data.get("server")), True)
    cursor.close()
    vk_api.messages.send(chat_id = VK_CHAT, random_id = 0, message = f"{user['name']} [{user['id']}] ({data['server']}): {data['text']}")
    return {"id": cursor.lastrowid, "text": data['text']}

@app.route("/messages/<message>", methods=["GET"])
def get_message(message):
    user = get_user()
    if not user: return {"error": "Invalid user"}, 401
    if user['rank'] < 1: return {"error": "Access denied"}, 403
    if message == "-1": cursor = sql_execute("SELECT * FROM `messages` ORDER BY `id` DESC LIMIT 1")
    else: cursor = sql_execute("SELECT * FROM `messages` WHERE `id` > '%s' LIMIT 25" % message)
    messages = cursor.fetchall()
    cursor.close()
    messages = list(filter(lambda msg: msg['type'] == "sms" and (msg['receiver'] == str(user['id']) or msg['user'] == str(user['id'])) or msg['type'] != "sms", messages))
    return {"messages": messages}

@app.route("/vk", methods=["GET"])
def get_vkcode():
    user = get_user()
    if not user: return {"error": "Invalid user"}, 401
    code = randomcode(6)
    vk_codes[code] = user['id']
    return {"code": code}

@app.route("/vk", methods=["DELETE"])
def del_vk():
    user = get_user()
    if not user: return {"error": "Invalid user"}, 401
    cursor = sql_execute("UPDATE `users` SET `vk` = NULL WHERE `id` = '%s'" % user['id'], True)
    cursor.close()
    return {"status": "Ok"} 

def online_timer(user):
    global users_online
    t = users_online[user]
    while True:
        if users_online[user] != t:
            break
        if time.time() - t >= 360:
            cursor = sql_execute("UPDATE `users` SET `online` = '0' WHERE `id` = '%s'" % user, True)
            cursor.close()
            del users_online[user]
            break
        time.sleep(1)

def vk_handler(event):
    if event.type == VkBotEventType.MESSAGE_NEW and event.chat_id == VK_CHAT:
        text = event.object.text
        user_id = event.object.from_id
        user_info = vk_api.users.get(user_ids = user_id)
        name = f"{user_info[0]['first_name']}  {user_info[0]['last_name']}"
        cursor = sql_execute("SELECT * FROM `users` WHERE `vk` = '%s'" % user_id)
        user = cursor.fetchone()
        cursor.close()
        if text.startswith("/connect"):
            if len(text.split()) < 2: 
                vk_api.messages.send(chat_id = event.chat_id, random_id = 0, message = f"{name}, используйте /connect [КОД ПРИВЯЗКИ]")
                return
            cursor.close()
            code = text.split()[1]
            smit_user = vk_codes.get(code)
            if not smit_user:
                vk_api.messages.send(chat_id = event.chat_id, random_id = 0, message = f"{name}, неверный код привязки.")
                return
            cursor = sql_execute("UPDATE `users` SET `vk` = NULL WHERE `vk` = '%s'" % user_id, True)
            cursor.close()
            cursor = sql_execute("UPDATE `users` SET `vk` = '%s' WHERE `id` = '%s'" % (user_id, smit_user), True)
            cursor.close()
            cursor = sql_execute("SELECT `name` FROM `users` WHERE `id` = '%s'" % smit_user)
            smit_name = cursor.fetchone()['name']
            cursor.close()
            del vk_codes[code]
            vk_api.messages.send(chat_id = event.chat_id, random_id = 0, message = f"{name}, ваш аккаунт успешно привязан к {smit_name}.")
        elif user and user['rank'] >= 1 and text == "/members":
            cursor = sql_execute("SELECT * FROM `users` WHERE `rank` > 0")
            members = cursor.fetchall()
            cursor.close()
            text = "🇷🇺 Пользователи чата:\n\n"
            for member in members:
                online = " | На " + member['server'] if member['online'] else ""
                if member['vk']: text += f"@id{member['vk']}({member['name']}) [{member['id']}]{online}\n"
                else: text += f"{member['name']} [{member['id']}]{online}\n"
            vk_api.messages.send(chat_id = event.chat_id, random_id = 0, message = text)
        elif user and user['rank'] >= 2 and text.startswith("/access"):
            id = text.split()[1]
            cursor = sql_execute("UPDATE `users` SET `rank` = '1' WHERE `id` = '%s'" % id, True)
            cursor.close()
            vk_api.messages.send(chat_id = event.chat_id, random_id = 0, message = "+")
        elif user and user['rank'] >= 2 and text.startswith("/deaccess"):
            id = text.split()[1]
            cursor = sql_execute("UPDATE `users` SET `rank` = '0' WHERE `id` = '%s'" % id, True)
            cursor.close()
            vk_api.messages.send(chat_id = event.chat_id, random_id = 0, message = "+")
        elif not text.startswith("."):
            if not user: 
                    vk_api.messages.send(chat_id = event.chat_id, disable_mentions = 1, random_id = 0, message = f"{name}, ваш ВКонтакте не подключён к аккаунту SAMP Chat\n\nКак подключить ВКонтакте:\n1. Введите /chat.menu в игре\n2. Нажмите привязать ВК\n3. Введите в данной беседе /connect [ПОЛУЧЕННЫЙ КОД]\n4. Ваш аккаунт привязан!\n\nНапишите . перед сообщением, что бы оно не отправлялось в чат")
                return
            if user['rank'] < 1:
                vk_api.messages.send(chat_id = event.chat_id, random_id = 0, message = f"{name}, вы не имеете доступа к написанию сообщений\n\nНапишите . перед сообщением, что бы оно не отправлялось в чат")
                return
            for attach in event.object.attachments:
                if attach_types.get(attach['type']): text += " {1099BE}[" + attach_types[attach['type']] + "]"
                if attach['type'] == "audio_message": text += " {1099BE}[Голосовое сообщение: " + recognize_url(attach['audio_message']['link_ogg']) + "]"
            cursor = sql_execute("INSERT INTO `messages` (`text`, `user`, `name`, `type`) VALUES ('%s', '%s', '%s', 'vk')" % (text.strip(), user['id'], user['name']), True)
            cursor.close()

def vk_listening():
    while True:
        try:
            longpoll = VkBotLongPoll(vk, GROUP_ID)
            for event in longpoll.listen():
                threading.Thread(target=vk_handler, args=(event,)).start()
        except Exception: time.sleep(1)

threading.Thread(target=vk_listening, daemon=True).start()
app.run(HOST_URL, HOST_PORT)

 

