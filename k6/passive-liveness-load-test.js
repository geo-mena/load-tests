import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');

// Test configuration - can be overridden via environment variables
const DEFAULT_CONFIG = {
  SERVER_HOST: __ENV.SERVER_HOST || 'localhost',
  SERVER_PORT: __ENV.SERVER_PORT || '8080',
  TPS: parseInt(__ENV.TPS) || 4,
  DURATION: __ENV.DURATION || '5m',
  RAMP_UP: __ENV.RAMP_UP || '30s',
  RAMP_DOWN: __ENV.RAMP_DOWN || '30s'
};

// Load test payload
const payload = JSON.stringify({
  tokenImage: __ENV.TOKEN_IMAGE || "BASE64_ENCODED_IMAGE_HERE",
  extraData: __ENV.EXTRA_DATA || "k6-load-test-request"
});

// Test options configuration
export let options = {
  stages: [
    { duration: DEFAULT_CONFIG.RAMP_UP, target: DEFAULT_CONFIG.TPS },
    { duration: DEFAULT_CONFIG.DURATION, target: DEFAULT_CONFIG.TPS },
    { duration: DEFAULT_CONFIG.RAMP_DOWN, target: 0 }
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'], // 95% of requests must complete below 3s
    http_req_failed: ['rate<0.01'],    // Error rate must be below 1%
    'http_req_duration{expected_response:true}': ['p(90)<2000'], // 90% of successful requests below 2s
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

const baseURL = `http://${DEFAULT_CONFIG.SERVER_HOST}:${DEFAULT_CONFIG.SERVER_PORT}`;
const endpoint = '/api/v1/selphid/passive-liveness/evaluate/token';

export default function() {
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    timeout: '30s',
  };

  const response = http.post(`${baseURL}${endpoint}`, payload, params);
  
  // Validate response
  const isSuccess = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 3000ms': (r) => r.timings.duration < 3000,
    'response has body': (r) => r.body && r.body.length > 0,
    'content type is JSON': (r) => r.headers['Content-Type'] && r.headers['Content-Type'].includes('application/json'),
  });

  errorRate.add(!isSuccess);

  // Think time to achieve desired TPS
  sleep(1);
}

export function handleSummary(data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const tps = DEFAULT_CONFIG.TPS;
  
  return {
    [`results/k6-${tps}tps-${timestamp}-summary.json`]: JSON.stringify(data, null, 2),
    [`results/k6-${tps}tps-${timestamp}-summary.html`]: htmlReport(data, tps),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function htmlReport(data, tps) {
  const metrics = data.metrics;
  
  return `
<!DOCTYPE html>
<html>
<head>
    <title>K6 Load Test Report - ${tps} TPS</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2196F3; color: white; padding: 20px; border-radius: 5px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-top: 20px; }
        .metric-card { background: #f5f5f5; padding: 15px; border-radius: 5px; border-left: 4px solid #2196F3; }
        .metric-title { font-weight: bold; margin-bottom: 10px; }
        .metric-value { font-size: 1.2em; color: #333; }
        .threshold-pass { color: #4CAF50; }
        .threshold-fail { color: #F44336; }
    </style>
</head>
<body>
    <div class="header">
        <h1>K6 Load Test Results - ${tps} TPS</h1>
        <p>Generated: ${new Date().toISOString()}</p>
        <p>Test Duration: ${data.state.testRunDurationMs}ms</p>
    </div>
    
    <div class="metrics">
        <div class="metric-card">
            <div class="metric-title">HTTP Requests</div>
            <div class="metric-value">${metrics.http_reqs.values.count} total</div>
            <div class="metric-value">${metrics.http_reqs.values.rate.toFixed(2)} req/s</div>
        </div>
        
        <div class="metric-card">
            <div class="metric-title">Response Time</div>
            <div class="metric-value">Avg: ${metrics.http_req_duration.values.avg.toFixed(2)}ms</div>
            <div class="metric-value">P95: ${metrics.http_req_duration.values['p(95)'].toFixed(2)}ms</div>
            <div class="metric-value">P99: ${metrics.http_req_duration.values['p(99)'].toFixed(2)}ms</div>
        </div>
        
        <div class="metric-card">
            <div class="metric-title">Success Rate</div>
            <div class="metric-value">${((1 - metrics.http_req_failed.values.rate) * 100).toFixed(2)}%</div>
            <div class="metric-value">Failed: ${metrics.http_req_failed.values.fails || 0}</div>
        </div>
    </div>
</body>
</html>`;
}

function textSummary(data) {
  return `
K6 Load Test Summary
=====================
Target TPS: ${DEFAULT_CONFIG.TPS}
Duration: ${DEFAULT_CONFIG.DURATION}
Total Requests: ${data.metrics.http_reqs.values.count}
Request Rate: ${data.metrics.http_reqs.values.rate.toFixed(2)} req/s
Success Rate: ${((1 - data.metrics.http_req_failed.values.rate) * 100).toFixed(2)}%

Response Times:
- Average: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms
- P90: ${data.metrics.http_req_duration.values['p(90)'].toFixed(2)}ms
- P95: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms
- P99: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms
`;
}