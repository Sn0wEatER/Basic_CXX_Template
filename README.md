## How to use
### 1. create a vscode dev-container
**step_1**: set environment variable.
```bash
cd Basic_CXX_Template-main
export PROJECT_NAME="<your project name>"
```
**step_2**: create the dev-container with docker-compose.
```bash
docker-compose up -d --build
```

### 2. create a c++ empty project
```bash
cd Basic_CXX_Template-main
chmod +x create_cpp_project.sh
./create_cpp_project.sh
```
