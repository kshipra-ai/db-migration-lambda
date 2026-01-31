const { LambdaClient, InvokeCommand } = require('@aws-sdk/client-lambda');

async function queryDB(query) {
  const client = new LambdaClient({ region: 'ca-central-1' });
  
  const payload = JSON.stringify({
    queryOnly: true,
    query: query
  });
  
  const command = new InvokeCommand({
    FunctionName: 'lambdaFn-db-migration-prod',
    Payload: Buffer.from(payload)
  });
  
  const response = await client.send(command);
  const result = JSON.parse(Buffer.from(response.Payload).toString());
  return result;
}

async function main() {
  const query = `SELECT 
    config_value->'referrer_reward'->>'type' as referrer_type,
    config_value->'referee_reward'->>'type' as referee_type
  FROM kshipra_core.system_configurations 
  WHERE config_key = 'referral_system'`;
  
  const result = await queryDB(query);
  console.log(JSON.stringify(result, null, 2));
}

main();
