import random
import os

endpoints = [
    ('/api/items', 'GET', 200, 0.04, 0.2),
    ('/api/items', 'POST', 201, 0.08, 0.3),
    ('/api/items/1', 'GET', 200, 0.02, 0.1),
    ('/api/items/2', 'DELETE', 204, 0.03, 0.1),
    ('/health', 'GET', 200, 0.002, 0.01),
    ('/metrics', 'GET', 200, 0.015, 0.05),
    ('/api/items/simulate-500', 'GET', 500, 0.5, 2.8),
    ('/api/slow-query', 'GET', 200, 1.2, 4.8),
    ('/api/unknown', 'GET', 404, 0.005, 0.02),
]

clients = ['10.0.1.25', '10.0.1.84', '172.31.14.92', '192.168.1.105', '54.210.88.12']
user_agents = ['Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', 'ELB-HealthChecker/2.0', 'Prometheus/2.45.0', 'curl/7.88.1']

lines = []
for i in range(350):
    minute = i % 15
    second = random.randint(0, 59)
    timestamp = f"21/Nov/2026:22:{minute:02d}:{second:02d} +0000"
    client = random.choice(clients)
    
    r = random.random()
    if r < 0.35:
        ep, method, status, min_t, max_t = ('/health', 'GET', 200, 0.002, 0.01)
    elif r < 0.65:
        ep, method, status, min_t, max_t = ('/api/items', 'GET', 200, 0.03, 0.15)
    elif r < 0.78:
        ep, method, status, min_t, max_t = ('/metrics', 'GET', 200, 0.01, 0.05)
    elif r < 0.88:
        ep, method, status, min_t, max_t = ('/api/items', 'POST', 201, 0.06, 0.25)
    elif r < 0.94:
        status = 500 if minute in [5, 6, 7] else 200
        ep, method, min_t, max_t = ('/api/items/simulate-500', 'GET', 0.8, 3.5)
    else:
        ep, method, status, min_t, max_t = random.choice(endpoints)
        if minute in [5, 6] and random.random() < 0.4:
            status = 503

    duration = round(random.uniform(min_t, max_t), 3)
    bytes_sent = random.randint(120, 4800)
    ua = random.choice(user_agents)

    log_entry = f'{client} - - [{timestamp}] "{method} {ep} HTTP/1.1" {status} {bytes_sent} {duration:.3f} "{ua}"'
    lines.append(log_entry)

os.makedirs('sample', exist_ok=True)
with open('sample/access.log', 'w') as f:
    f.write('\n'.join(lines) + '\n')
print(f"Generated {len(lines)} log lines into sample/access.log")
