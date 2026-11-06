"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { addComment, createTask, generateRecurring, saveDocumentRequest, toggleChecklist, transitionTask } from "./service";
import { taskFromFormData } from "./validation";
export type TaskState={error?:string;fieldErrors?:Record<string,string[]>}; const fail=(e:unknown)=>e instanceof Error?e.message:"Unable to update task.";
export async function createTaskAction(_:TaskState,f:FormData):Promise<TaskState>{const p=taskFromFormData(f);if(!p.success)return{fieldErrors:p.error.flatten().fieldErrors};try{const id=await createTask(p.data);redirect(`/app/tasks/${id}?created=1`)}catch(e){return{error:fail(e)}}}
export async function transitionTaskAction(f:FormData){const id=String(f.get("taskId"));try{await transitionTask(id,String(f.get("updatedAt")),String(f.get("status")),String(f.get("note")??""));revalidatePath(`/app/tasks/${id}`);revalidatePath("/app/tasks");}catch(e){redirect(`/app/tasks/${id}?error=${encodeURIComponent(fail(e))}`)}}
export async function checklistAction(f:FormData){const id=String(f.get("taskId"));await toggleChecklist(id,String(f.get("itemId")),f.get("complete")==="true");revalidatePath(`/app/tasks/${id}`)}
export async function commentAction(f:FormData){const id=String(f.get("taskId"));await addComment(id,String(f.get("body")??""));revalidatePath(`/app/tasks/${id}`)}
export async function documentRequestAction(f:FormData){const id=String(f.get("taskId"));await saveDocumentRequest(id,String(f.get("requestId")??"")||undefined,String(f.get("label")??""),String(f.get("status")??"REQUESTED"));revalidatePath(`/app/tasks/${id}`)}
export async function generateRecurringAction(_:TaskState,f:FormData):Promise<TaskState>{try{const id=await generateRecurring(String(f.get("templateId")),String(f.get("clientId")),String(f.get("periodStart")),String(f.get("periodEnd")));redirect(`/app/tasks/${id}?generated=1`)}catch(e){return{error:fail(e)}}}
