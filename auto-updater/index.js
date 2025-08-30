import { default as axios } from "axios";
import Dockerode from "dockerode";

const docker = new Dockerode({ socketPath: "/var/run/docker.sock" });

const REGISTRY_URL = `${process.env.GITEA_REGISTRY ?? "gitea.elgem.be"}`;
const IMAGE_TAG = `${process.env.IMAGE_TAG ?? "latest"}`;
const SLEEP_INTERVAL = `${process.env.SLEEP_INTERVAL ?? 5}`;

const registry = axios.create({
  baseURL: `https://${REGISTRY_URL}`,
  auth: {
    username: "admin",
    password: "b65cc487878182a2f5124343ec23a56d56cf3783",
  },
});

const auth = {
  username: "admin",
  password: "b65cc487878182a2f5124343ec23a56d56cf3783",
  auth: "",
  serveraddress: REGISTRY_URL,
};

async function getImageList() {
  const result = await registry.get(`/v2/_catalog`);
  return result.data.repositories;
}

async function getRegistryDigest(imageName) {
  try {
    const result = await registry.get(`/v2/${imageName}/manifests/latest`, {
      headers: {
        Accept: "application/vnd.docker.distribution.manifest.v2+json",
      },
    });

    return result.headers["docker-content-digest"];
  } catch (error) {
    handleAxiosError(error);
  }
}

async function getRunningDigest(imageName) {
  try {
    const image = docker.getImage(`${REGISTRY_URL}/${imageName}`);

    const inspect = await image.inspect();
    return inspect.RepoDigests[0].split("@")[1];
  } catch (error) {
    console.error(`❌ Error inspecting image ${imageName}:`, error);
    return undefined;
  }
}

function handleAxiosError(error) {
  if (error.response) {
    const { status, statusText, data } = error.response;
    console.error(`❌ HTTP ${status} - ${statusText}`);
    if (status === 401) {
      console.error("🔒 Unauthorized: Check your username or token.");
    }
    console.error("Details:", data);
  } else if (error.request) {
    console.error("❌ No response received:", error.request);
  } else {
    console.error("❌ Error:", error.message);
  }
}

async function processImage(imageName) {
  const registryDigest = await getRegistryDigest(imageName);
  const runningDigest = await getRunningDigest(imageName);
  console.log("Registry digest:", registryDigest);
  console.log("Running digest:", runningDigest);

  if (runningDigest == undefined) {
    console.log(`Container ${imageName} is not running`);
    console.log(`Creating container for ${imageName}`);
    await pullImage(imageName);
    await createContainer(imageName);
  } else if (runningDigest == registryDigest) {
    console.log(`Container ${imageName} is running but outdated`);
    console.log(`Updating container image for ${imageName}`);
    await pullImage(imageName);
    await updateContainer(imageName);
  }
}

async function createContainer(imageName) {
  console.log(`Creating container for ${imageName}`);
  const container = await docker.createContainer({
    Image: `${REGISTRY_URL}/${imageName}`,
    Tty: true,
  });
  await container.start();
}

async function updateContainer(imageName) {
  //Get container by image name
  console.log(`Updating container for ${imageName}`);
  const existingContainers = await docker.listContainers({
    all: true,
    filters: {
      ancestor: [`${REGISTRY_URL}/${imageName}`],
    },
  });
  const container = docker.getContainer(imageName);
  await container.stop();
  await container.remove();
  await createContainer(imageName);
}

async function pullImage(imageName) {
  let isFinished = false;

  docker.pull(
    `${REGISTRY_URL}/${imageName}`,
    { tag: "latest", authconfig: auth },
    async (err, stream) => {
      if (err) {
        console.error(`❌ Error pulling image ${imageName}:`, err);
        return;
      }

      docker.modem.followProgress(stream, onFinished, onProgress);

      async function onFinished(err, output) {
        isFinished = true;
        if (err) {
          console.error(`❌ Error pulling image ${imageName}:`, err);
          return;
        }
        console.log(`✅ Successfully pulled image ${imageName}`);
      }

      async function onProgress(event) {
        if (event.status) {
          console.log(`🔄 ${event.status}`);
        }
      }
    }
  );
  while (!isFinished) {
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
}

async function main() {
  while (true) {
    const imageList = await getImageList();
    for (const imageName of imageList) {
      await processImage(imageName);
    }
    await new Promise((resolve) => setTimeout(resolve, SLEEP_INTERVAL * 1000));
  }
}

main();
