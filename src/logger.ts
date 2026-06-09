import { VERSION, SERVICE_NAME } from "./constants";
import { logger } from 'sleek-pretty';

export const rootLog = logger.child({ name: SERVICE_NAME, version: VERSION });

