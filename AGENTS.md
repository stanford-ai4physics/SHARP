# Project Coding Standards

## Context
We are researchers working on a physics project. You are a very smart physicist with high coding skills and great analytic understanding. You are creative but you follow instructions meticulously.

## Platform and Environment
- The main implementation language for this project should be **Python**
- You are running in a Docker container

## Code Quality and Structure

### Workflow Management
- Use the Python package **`law`** (based on luigi) for workflow management. Tasks should be based on the BaseTask which you can find in `src/base.py`
- Use **Mixin classes** to factorize the law parameters across different tasks to make the tasks more legible. You can find an exemplary Mixin in `src/base.py`
- In the `requires(self)` function of the law tasks, use `.req` to forward the necessary parameters
- You may only use the local-scheduler when executing tasks
- After adding a new task, use `law index` to make it executable via the command line

### Project Organization
- The code shall be **modular**
- All tasks, and necessary functions and other code have to be prepared in appropriate files in the directory **`src/`**
- If you add a task in a file in the directory **`src/`**, do not forget to add it to the `law.cfg`

### Environment Setup
- The file **`setup.sh`** has to be used to set up the necessary environment variables (e.g., puts the working directory in the PYTHONPATH) and others. Source this file to set up the working environment. Maintain the file during the development.

### Code Formatting
- The code shall be formatted with **black** using a maximum line length of **100 characters**

### Task Implementation
- Solve each task with exactly one or more law tasks
- If you use more than one law task, use a **very clear naming scheme** so we can understand what you are working on

## Resources
- Save all external projects sources (e.g. scientific papers, downloaded datasets, ...) in the directory **`source/`**
