import 'dart:convert';
import 'dart:io';
import 'dart:math';

Map<String, int> relevance = {};

final reFile = File('relevance.json');

void refreshLoop() async {
  while (true) {
    print('Refresh Loop');

    for (var key in relevance.keys.toList()) {
      if (DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(relevance[key])) >
          Duration(days: 7)) {
        print('no longer relevant, removing ${key}');
        relevance.remove(key);
      } else {
        if (nameToTXTRecordsCache.containsKey(key)) {
          if (DateTime.now().difference(cacheTime[key]) >
              Duration(minutes: cacheTimeMinutes[key] - 3)) {
                
            await getName(key, useCache: false);
          }
        } else {
          await getName(key);
        }
      }
    }
    reFile.writeAsStringSync(json.encode(relevance));
    await Future.delayed(Duration(seconds: 60));
  }
}

Future main() async {
  if (reFile.existsSync()) {
    relevance = json.decode(reFile.readAsStringSync()).cast<String, int>();
  }

  refreshLoop();

  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    8053,
  );
  server.listen((event) {
    handleRequest(event);
  });
}

Map<String, List<String>> nameToTXTRecordsCache = {};

Map<String, DateTime> cacheTime = {};

Map<String, int> cacheTimeMinutes = {};

void handleRequest(HttpRequest request) async {
  print(request.uri.path);

  try {
    if (request.method == 'POST') {
      if (request.uri.path == '/multi-dns-query') {
        final content = await utf8.decoder.bind(request).join();
        var data = json.decode(content) as Map;
        print(data);

        if (data['type'] == 16 && data['names'].length <= 64) {
          final futures = <Future>[];

          final res = <String, List<String>>{};

          Future loadName(String name) async {
            relevance[name] = DateTime.now().millisecondsSinceEpoch;

            res[name] = await getName(name);
          }

          for (var name in data['names']) {
            futures.add(loadName(name));
          }
          await Future.wait(futures);
          request.response.write(json.encode({'type': 16, 'names': res}));
        } else {
          request.response.statusCode = HttpStatus.badRequest;
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
    }
  } catch (e) {
    request.response.statusCode = HttpStatus.internalServerError;
    print('Exception in handleRequest: $e');
  }
  await request.response.close();
}

Map<String, int> retryCount = {};

Future<List<String>> getName(String name, {bool useCache = true}) async {
  if (useCache) {
    if (nameToTXTRecordsCache.containsKey(name)) {
      if (DateTime.now().difference(cacheTime[name]) >
          Duration(minutes: cacheTimeMinutes[name])) {
        nameToTXTRecordsCache.remove(name);
        cacheTime.remove(name);
        cacheTimeMinutes.remove(name);
      } else {
        return nameToTXTRecordsCache[name];
      }
    }
  }

  print('Getting $name');

  try {
    List<String> answers = [];
    int i = 0;

    while (true) {
      i++;
      final res = await Process.run(
          'dig', ['+noall', '+answer', '@127.0.0.1', 'TXT', name]); // hmm...

      for (final String line in res.stdout.split('\n')) {
        if (line.isNotEmpty) {
          answers.add(line.split('"')[1]);
        }
      }
      if (answers.isNotEmpty) {
        break;
      }
      if (i > 5) {
        break;
      }
      await Future.delayed(Duration(milliseconds: 500));
    }

    print(answers);

    if (answers.isNotEmpty) {
      nameToTXTRecordsCache[name] = answers;
      cacheTime[name] = DateTime.now();
      cacheTimeMinutes[name] = Random().nextInt(30) + 30;
    } else {
      final count = retryCount[name] ?? 0;
      if (count > 3) {
        relevance.remove(name);
        retryCount.remove(name);
      } else {
        retryCount[name] = count + 1;
      }
    }

    return answers;
  } catch (e, st) {
    print(e);

    return null;
  }
}
