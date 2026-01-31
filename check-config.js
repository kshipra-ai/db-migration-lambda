const { Client } = require('pg');

const dbConfig = {
  host: 'lambdafn-production.cl466woecfi5.ca-central-1.rds.amazonaws.com',
  port: 5432,
  database: 'kshipra_production',
  user: 'kshipra_admin',
  password: 'c]gJNbbOveipM3UduAhaz8jZNsG=zz<T',
  ssl: { rejectUnauthorized: false }
};

async function checkConfig() {
  const client = new Client(dbConfig);
  try {
    await client.connect();
    console.log('Connected to database');
    
    const result = await client.query(`
      SELECT 
        config_value->'referrer_reward'->>'type' as referrer_type,
        config_value->'referee_reward'->>'type' as referee_type,
        config_value
      FROM kshipra_core.system_configurations 
      WHERE config_key = 'referral_system'
    `);
    
    console.log('\nReferral System Config:');
    console.log('Referrer reward type:', result.rows[0].referrer_type);
    console.log('Referee reward type:', result.rows[0].referee_type);
    console.log('\nFull config:', JSON.stringify(result.rows[0].config_value, null, 2));
    
    await client.end();
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkConfig();
